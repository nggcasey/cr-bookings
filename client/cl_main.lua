-- ==========================================
--  MAIN MENU FUNCTIONS
-- ==========================================

RegisterCommand('bookings', function()
    OpenBookingsMainMenu()
end)

-- Function: Open the "Bookings" main menu
function OpenBookingsMainMenu()
    -- Register the main booking menu
    lib.registerContext({
        id = 'booking_main_menu',
        title = 'Bookings Main Menu',
        options = {
            {
                title = 'Find Service',
                description = 'Find a service to make a booking',
                onSelect = function()
                    OpenFindServiceMenu()
                end
            },
            {
                title = 'My Bookings',
                description = 'List your upcoming appointments',
                --menu = 'my_bookings_menu',
                onSelect = function()
                    OpenMyBookingsMenu()
                end
            },
            {
                title = 'My Availability',
                description = 'View or Edit your business availability',
                onSelect = function()
                    OpenMyAvailabilityMenu()
                end
            },
        }
    })

    --Open the menu immediately after registering
    lib.showContext('booking_main_menu')
end

-- ==========================================
--  FIND A SERVICE / MAKE A BOOKING FUNCTIONS
-- ==========================================

-- Function: Open the "Find a Service" menu
function OpenFindServiceMenu()
    local options = {}

    for businessKey, businessData in pairs(Config.Businesses) do
        local subOptions = {}

        for _, appointment in ipairs(businessData.appointmentTypes) do
            table.insert(subOptions, {
                title = appointment.label,
                description = appointment.description .. "\nDuration: "..appointment.duration.." min | Fee: $" .. appointment.fee,
                onSelect = function()
                    --OpenAppointmentSelectionMenu(businessKey, appointment.label)
                    OpenAppointmentSelectionMenu(businessKey, appointment)
                end
            })
        end

        table.insert(options, {
            title = businessData.label,
            icon = businessData.icon,
            menu = businessKey .. '_appointments'
        })

        -- Register submenus dynamically
        lib.registerContext({
            id = businessKey .. '_appointments',
            title = businessData.label .. ' - Appointments',
            menu = 'find_service_menu',
            options = subOptions
        })
    end

    -- Register the Find Service Menu dynamically
    lib.registerContext({
        id = 'find_service_menu',
        title = 'Find a Service',
        options = options
    })

    -- Open the menu immediately after registering
    lib.showContext('find_service_menu')
end

-- Expanding the appointment selection menu
function OpenAppointmentSelectionMenu(businessKey, appointmentType)
    lib.registerContext({
        id = 'appointment_selection_menu',
        title = ('%s - Booking Options'):format(Config.Businesses[businessKey].label),
        options = {
            {
                title = '🔍 Filter by Staff',
                description = 'Choose specific staff members to check availability',
                onSelect = function()
                    SelectStaffForBooking(businessKey, appointmentType)
                end
            },
            {
                title = '📅 Search All',
                description = 'Find availability across all staff',
                onSelect = function()
                    FetchAvailableDays(businessKey, appointmentType, nil)
                end
            }
        }
    })
    lib.showContext('appointment_selection_menu')
end

-- Select input for filtering by staff
function SelectStaffForBooking(businessKey, appointmentType)
    lib.callback('cr-bookings:server:getAvailableStaff', false, function(staffList)
        if not staffList or #staffList == 0 then
            --TODO: Show a context menu with a greyed out option - Notify message is pretty meh
            lib.notify({ type = 'error', description = 'No available staff found for this business.' })
            return
        end

        local input = lib.inputDialog('Select Staff Members', {
            {
                type = 'select', --Only allow select: Multi-select is causing me too many headaches, cant be bothered dealing with it
                label = 'Choose Staff',
                options = staffList,
            }
        })

        if not input then return end
        local selectedStaff = input[1] -- Multi-selected staff
        if Config.DebugMode then
            print('[DEBUG] Staff IDs selected: '..json.encode(selectedStaff))
        end

        FetchAvailableDays(businessKey, appointmentType, selectedStaff)
    end, businessKey)
end

-- Fetch available days for business - Optional selected staff
function FetchAvailableDays(businessKey, appointmentType, staffId)

    if Config.DebugMode then
        local debugStaffId = staffId or 'None' -- Ensure staffId is always a string
        print('Staff CID: '..debugStaffId)
    end

    lib.callback('cr-bookings:server:getAvailableDays', false, function(daysList)
        if not daysList or #daysList == 0 then
            lib.notify({ type = 'error', description = 'No available days for this selection.' })
            return
        end

        if Config.DebugMode then
            print(json.encode(daysList))
        end

        local options = {}
        for _, day in ipairs(daysList) do
            table.insert(options, {
                title = day.formatted_day,
                onSelect = function()
                    --OpenDayScheduleMenu(day.timestamp, appointmentType, businessKey, staffId)
                    OpenSelectAvailabilitySlotMenu(day.timestamp, appointmentType, businessKey, staffId)
                end
            })
        end

        lib.registerContext({
            id = 'available_days_menu',
            title = 'Select Available Day',
            options = options
        })
        lib.showContext('available_days_menu')
    end, businessKey, staffId)
end

function OpenSelectAvailabilitySlotMenu(dayTimestamp, appointmentType, businessKey, staffId)
    lib.callback('cr-bookings:server:getAvailabilitySlots', false, function(availabilitySlots)
        if not availabilitySlots or type(availabilitySlots) ~= "table" then
            print("[ERROR] No availability slots received.")
            availabilitySlots = {} -- Prevent crash by setting an empty table
        end

        local options = {}

        for _, slot in ipairs(availabilitySlots) do
            local metadata = {}

            -- Show booked appointments inside the slot
            if slot.booked_appointments and #slot.booked_appointments > 0 then
                for _, booking in ipairs(slot.booked_appointments) do
                    table.insert(metadata, {label = "Booked", value = string.format("%s - %s", booking.start_time, booking.end_time)})
                end
            else
                table.insert(metadata, {label = "Booked", value = "None"})
            end

            table.insert(options, {
                title = string.format("%s - %s to %s", slot.staff_name, slot.formatted_start, slot.formatted_end),
                description = string.format("Select this availability slot\n%s", slot.formatted_date),
                --description = slot.staff_name.."\nSelect this availability slot",
                icon = "user-check",
                iconColor = 'green',
                metadata = metadata,
                onSelect = function()
                    OpenEnterAppointmentDetailsDialog(dayTimestamp, appointmentType, businessKey, slot.staff_cid, slot, slot.formatted_date)
                end
            })
        end

        lib.registerContext({
            id = 'availability_slot_menu',
            title = 'Select Availability Slot',
            options = options
        })
        lib.showContext('availability_slot_menu')

    end, dayTimestamp, businessKey, staffId)
end

function OpenEnterAppointmentDetailsDialog(dayTimestamp, appointmentType, businessKey, staffId, slot, formattedDate)
    -- Get unavailable times for reference
    local unavailableTimes = ""
    if slot.booked_appointments and #slot.booked_appointments > 0 then
        for _, booking in ipairs(slot.booked_appointments) do
            unavailableTimes = unavailableTimes .. string.format("%s - %s\n", booking.start_time, booking.end_time)
        end
    else
        unavailableTimes = "None"
    end

    -- Open input dialog
    local input = lib.inputDialog("Enter Appointment Details", {
        {
            type = "input",
            label = "Date",
            default = formattedDate,
            disabled = true
        },
        {
            type = "input",
            label = "Staff Member",
            default = slot.staff_name or "Staff name not found",
            disabled = true
        },
        {
            type = "input",
            label = "Appointment Type",
            default = appointmentType.label,
            disabled = true
        },
        {
            type = "input",
            label = "Appointment Length",
            default = string.format("%d min (+%d min buffer)", appointmentType.duration, appointmentType.buffer),
            disabled = true
        },
        {
            type = "input",
            label = "Appointment Fee",
            default = string.format("$%d", appointmentType.fee),
            disabled = true
        },
        {
            type = "slider",
            label = "Hour",
            min = tonumber(slot.formatted_start:sub(1,2)),
            max = tonumber(slot.formatted_end:sub(1,2)),
            step = 1,
            required = true
        },
        {
            type = "slider",
            label = "Minute",
            min = 0,
            max = 55,
            step = 5,
            required = true
        },
        {
            type = "textarea",
            label = "Booking Notes (optional)",
            autosize = true
        },
        {
            type = "textarea",
            label = "Unavailable Times",
            default = unavailableTimes,
            autosize = true,
            disabled = true
        }
    })

    if not input then return end -- User canceled

    local selectedHour = input[6]
    local selectedMinute = input[7]
    local bookingNotes = input[8] or ""
    local formattedTime = string.format("%02d:%02d", selectedHour, selectedMinute)

    ConfirmAppointmentSelection(dayTimestamp, appointmentType, businessKey, staffId, formattedTime, bookingNotes)
end

function ConfirmAppointmentSelection(dayTimestamp, appointmentType, businessKey, staffId, formattedTime, bookingNotes)

    if not staffId then
        lib.alertDialog({ header = "Unable to submit booking", content = "An error occurred while booking - Staff CitizenID not found, please report this to the development team"})
    end

    lib.callback('cr-bookings:server:bookAppointment', false, function(success)
        if success then
            lib.notify({ title = "Booking Confirmed", description = "Your appointment has been booked!", type = "success" })
        else
            lib.notify({ title = "Booking Failed", description = "An error occurred while booking.", type = "error" })
        end
    end, dayTimestamp, appointmentType, businessKey, staffId, formattedTime, bookingNotes)
end


-- function OpenDayScheduleMenu(dayTimestamp, appointmentType, businessKey, staffId)
--     if Config.DebugMode then
--         local debugStaffId = staffId or 'None'
--         print(string.format('Day Timestamp: %i | Business Key: %s | Staff CID: %s', dayTimestamp, businessKey, debugStaffId))
--     end

--     lib.callback('cr-bookings:server:getDaySchedule', false, function(scheduleBlocks)
--         if Config.DebugMode then
--             print('[DEBUG] Received Schedule Blocks: '..json.encode(scheduleBlocks))
--         end

--         local options = {}

--         for _, block in ipairs(scheduleBlocks) do
--             local timeLabel = string.format('%s - %s', block.formatted_start, block.formatted_end)
--             local staffLabel = block.staff_name or ('Staff: ' .. block.staff_cid)
--             local businessLabel = block.business_label or 'Unknown Business'
--             local blockStatus = block.block_type == "free" and "✅ Free" or "❌ Busy"

--             table.insert(options, {
--                 title = string.format('%s - %s', staffLabel, blockStatus),
--                 description = string.format("%s\n🏢 %s", timeLabel, businessLabel),
--                 disabled = block.block_type ~= "free",
--                 onSelect = function()
--                     OpenSelectStartTimeMenu(dayTimestamp, appointmentType, businessKey, block.staff_cid, block)
--                 end
--             })
--         end

--         lib.registerContext({
--             id = 'day_schedule_menu',
--             title = 'Select Available Time Block',
--             options = options
--         })
--         lib.showContext('day_schedule_menu')

--     end, dayTimestamp, appointmentType, businessKey, staffId)
-- end

-- function OpenSelectStartTimeMenu(dayTimestamp, appointmentType, businessKey, staffId, block)

--     if not dayTimestamp or not appointmentType or not businessKey or not staffId or not block then
--         local alert = lib.alertDialog({
--             header = 'Error - Missing Parameters',
--             content = 'Unable to the Open Select Start Time Menu due to a missing parameter. Please report this bug to the development team.'
--         })
--     end

--     local duration = appointmentType.duration or 0
--     local buffer = appointmentType.buffer or 0

--     -- Convert block's start/end time to numerical values
--     local startTimeParts = { block.formatted_start:match("(%d+):(%d+)") }
--     local endTimeParts = { block.formatted_end:match("(%d+):(%d+)") }

--     local startHour, startMinute = tonumber(startTimeParts[1]), tonumber(startTimeParts[2])
--     local endHour, endMinute = tonumber(endTimeParts[1]), tonumber(endTimeParts[2])

--     -- Fetch existing appointments to prevent conflicts
--     lib.callback('cr-bookings:server:getAvailableStartTimes', false, function(bookedSlots)

--         -- Open the input dialog with sliders for time selection and a text box for notes
--         local input = lib.inputDialog("Set Appointment Time", {
--             {
--                 type = 'slider',
--                 label = 'Hour',
--                 min = startHour,
--                 max = endHour,
--                 step = 1,
--                 required = true
--             },
--             {
--                 type = 'slider',
--                 label = 'Minute',
--                 min = 0,
--                 max = 59,
--                 step = 5, -- Adjustable step size
--                 required = true
--             },
--             {
--                 type = 'input',
--                 label = 'Booking Notes (optional)',
--                 required = false
--             }
--         })

--         if not input then return end -- User canceled

--         local selectedHour = input[1]
--         local selectedMinute = input[2]
--         local bookingNotes = input[3] or ""

--         local formattedTime = string.format("%02d:%02d", selectedHour, selectedMinute)

--         -- Ensure the selected time does not overlap with existing bookings
--         local function isTimeBlocked(hour, minute)
--             local timeString = string.format('%02d:%02d', hour, minute)
--             for _, slot in ipairs(bookedSlots) do
--                 if timeString >= slot.formatted_start and timeString < slot.formatted_end then
--                     return true -- Time is already booked
--                 end
--             end
--             return false
--         end

--         if isTimeBlocked(selectedHour, selectedMinute) then
--             lib.notify({ title = "Time Unavailable", description = "This time slot is already booked!", type = "error" })
--             OpenSelectStartTimeMenu(dayTimestamp, appointmentType, businessKey, staffId, block) -- Reopen menu
--             return
--         end

--         -- Proceed with appointment confirmation
--         ConfirmAppointmentSelection(dayTimestamp, appointmentType, businessKey, staffId, formattedTime, bookingNotes)

--     end, dayTimestamp, businessKey, staffId)
-- end






-- function SelectBookingTime(startTime, endTime, staffCid, dateStr)
--     local input = lib.inputDialog('Select Booking Time', {
--         { type = 'slider', label = 'Start Hour', min = math.floor(startTime / 60), max = math.floor(endTime / 60), required = true },
--         { type = 'slider', label = 'Start Minute', min = 0, max = 59, step = 5, required = true }
--     })

--     if not input then return end

--     local selectedHour = tonumber(input[1])
--     local selectedMinute = tonumber(input[2])
--     local finalStartTime = (selectedHour * 60) + selectedMinute

--     if finalStartTime < startTime or finalStartTime >= endTime then
--         lib.notify({ type = 'error', description = 'Invalid booking time. Please select within available hours.' })
--         return
--     end

--     ConfirmBooking(staffCid, dateStr, finalStartTime)
-- end

--TODO: Why the fuck do i have TWO ConfirmBooking functions? ConfirmBooking() and ConfirmBookingSelection()
-- function ConfirmBooking(staffCid, dateStr, startTime)
--     local confirm = lib.alertDialog({
--         header = 'Confirm Booking',
--         content = ('Confirm your booking on **%s** at **%02d:%02d**?'):format(dateStr, math.floor(startTime / 60), startTime % 60),
--         centered = true,
--         cancel = true
--     })

--     if confirm ~= 'confirm' then return end

--     TriggerServerEvent('cr-bookings:server:createBooking', staffCid, dateStr, startTime)
-- end

--TODO: Why the fuck do i have TWO ConfirmBooking functions? ConfirmBooking() and ConfirmBookingSelection()
-- Confirm booking and send request to the server
-- function ConfirmBookingSelection(businessKey, appointmentType, selectedDate, startHour, startMinute, staffIds)
--     local confirm = lib.alertDialog({
--         header = 'Confirm Booking',
--         content = ('Confirm your booking for **%s** on **%s** at **%02d:%02d**?'):format(appointmentType, selectedDate, startHour, startMinute),
--         centered = true,
--         cancel = true
--     })

--     if confirm ~= 'confirm' then return end

--     TriggerServerEvent('cr-bookings:server:createBooking', businessKey, appointmentType, selectedDate, startHour, startMinute, staffIds)
-- end

-- Allow users to input a booking time
-- function OpenBookingTimeSelection(businessKey, appointmentType, selectedDate, staffIds)
--     local input = lib.inputDialog('Enter Booking Time', {
--         { type = 'date', label = 'Selected Date', default = selectedDate, disabled = true },
--         { type = 'slider', label = 'Start Hour', min = 0, max = 23, required = true },
--         { type = 'slider', label = 'Start Minute', min = 0, max = 59, step = 10, required = true }
--     })

--     if not input then return end
--     local startHour, startMinute = tonumber(input[2]), tonumber(input[3])

--     lib.callback('cr-bookings:server:checkBookingConflicts', false, function(conflictExists)
--         if conflictExists then
--             lib.notify({ type = 'error', description = 'Selected time is unavailable. Please choose another time.' })
--             return
--         end

--         ConfirmBookingSelection(businessKey, appointmentType, selectedDate, startHour, startMinute, staffIds)
--     end, businessKey, selectedDate, startHour, startMinute, staffIds)
-- end

-- ==========================================
--  MY UPCOMING BOOKING FUNCTIONS
-- ==========================================

--Function: Open the My Bookings Menu
function OpenMyBookingsMenu()
    local options = {
        {
            title = 'Tuning Appointment at NRMA',
            description = 'Date: 28-Feb-2025\n Time: 1500-1530\nClient: Jimmy BARNES'
        },
        {
            title = 'Standard Trial at NSW Courts',
            description = 'Date: 1-Feb-2025\n Time: 1900-1930\nStaff: Judy JUSTICE'
        },
    }

    --Register & Show "My Bookings Menu"
    lib.registerContext({
        id = 'my_bookings_menu',
        title = 'My Bookings',
        options = options
    })

    lib.showContext('my_bookings_menu')

end

-- ==========================================
--  MY AVAILABILITY FUNCTIONS
-- ==========================================

-- Function: Open My Availability Menu
function OpenMyAvailabilityMenu()
    local options = {
        {
            title = "Set Availability",
            description = "Add new available time slots",
            onSelect = function()
                SelectBusinessForAvailability()
            end
        },
        {
            title = "View Availability",
            description = "View or edit your existing availability",
            onSelect = function()
                ListExistingAvailability()
            end
        }
    }

    lib.registerContext({
        id = 'my_availability_menu',
        title = 'My Availability',
        options = options
    })

    lib.showContext('my_availability_menu')
end

-- Function: Select Business for Availability
function SelectBusinessForAvailability()
    local PlayerGroups = exports.qbx_core:GetGroups()
    local options = {}

    for businessKey, businessData in pairs(Config.Businesses) do
        if PlayerGroups[businessKey] then
            table.insert(options, {
                title = businessData.label,
                onSelect = function()
                    SetAvailabilityForBusiness(businessKey, businessData.label)
                end
            })
        end
    end

    if #options == 0 then
        lib.notify({ description = "You are not part of any businesses that allow bookings.", type = "error" })
        return
    end

    lib.registerContext({
        id = 'select_business_menu',
        title = 'Select Business',
        options = options
    })

    lib.showContext('select_business_menu')
end

-- Function: Set your availability for a business
function SetAvailabilityForBusiness(businessKey, businessLabel)
    -- Input Dialog
    local input = lib.inputDialog(('Set Availability - %s'):format(businessLabel), {
        { --Input 1 (Display server time)
            type = 'input',
            label = 'Enter availability in server time only',
            default = 'Server time is Sydney/Australia.',
            disabled = true
        },
        { --Input 2 (Date)
            type = 'date',
            label = 'Date',
            format = 'DD/MM/YYYY',
            default = true,
            returnString = true,
            required = true
        },
        { --Input 3 (From Hour)
            type = 'slider',
            label = 'From Hour',
            min = 0,
            max = 23,
            required = true
        },
        { --Input 4 (From Minute)
            type = 'slider',
            label = 'From Minute',
            min = 0,
            max = 59,
            step = 10,
            required = true
        },
        { --Input 5 (To Hour)
            type = 'slider',
            label = 'To Hour',
            min = 0,
            max = 23,
            required = true
        },
        { --Input 6 (To Minute)
            type = 'slider',
            label = 'To Minute',
            min = 0,
            max = 59,
            step = 10,
            required = true
        },
        { --Input 7 (Notes)
            type = 'textarea',
            label = 'Notes',
            required = false
        },
    })

    -- Handle cancellation
    if not input then return end

    -- Extract values
    local dateStr  = input[2]  -- e.g., "24/02/2025"
    local fromHour = tonumber(input[3])
    local fromMin  = tonumber(input[4])
    local toHour   = tonumber(input[5])
    local toMin    = tonumber(input[6])
    local notes    = input[7] or ""

    -- Validate extracted values
    if not dateStr or not fromHour or not fromMin or not toHour or not toMin then
        print("Error: Invalid input received.")
        return
    end

    -- Parse the date (Convert "DD/MM/YYYY" to numbers)
    local day, month, year = dateStr:match("(%d+)/(%d+)/(%d+)")
    if not day or not month or not year then
        print("Error: Invalid date format received.")
        return
    end

    -- Convert date to numbers
    day = tonumber(day)
    month = tonumber(month)
    year = tonumber(year)

    -- Convert to formatted time strings
    local fromTimeFormatted = string.format("%02d:%02d", fromHour, fromMin)
    local toTimeFormatted = string.format("%02d:%02d", toHour, toMin)

    -- Confirm before submission
    local confirm = lib.inputDialog(('Confirm Availability - %s'):format(businessLabel), {
        { -- Server time notice
            type = 'input',
            label = 'Availability in server time only',
            default = 'Server time is Sydney/Australia.',
            disabled = true
        },
        { -- Date
            type = 'input',
            label = 'Date',
            default = dateStr,
            disabled = true
        },
        { -- From Time
            type = 'input',
            label = 'From Time',
            default = fromTimeFormatted,
            disabled = true
        },
        { -- To Time
            type = 'input',
            label = 'To Time',
            default = toTimeFormatted,
            disabled = true
        },
        { -- Notes
            type = 'textarea',
            label = 'Notes',
            default = notes,
            disabled = true
        },
    })

    -- Handle cancellation
    if not confirm then return end

    -- Send to server as a table
    local availabilityData = {
        businessKey = businessKey,
        day = day,
        month = month,
        year = year,
        fromHour = fromHour,
        fromMin = fromMin,
        toHour = toHour,
        toMin = toMin,
        notes = notes
    }

    TriggerServerEvent("cr-bookings:server:setAvailability", availabilityData)
end

---- Function: Shows your existing availability
function ListExistingAvailability()
    -- Request availability data from the server
    lib.callback('cr-bookings:server:getMyAvailability', false, function(availabilityList)
        local options = {}

        -- If no availability is found, show a message
        if not availabilityList or #availabilityList == 0 then
            table.insert(options, {
                title = 'No Active Availability',
                description = 'You currently have no availability records. Add one using the menu.',
                disabled = true
            })
        else
            -- Loop through availability entries and add them to the menu
            for _, availability in ipairs(availabilityList) do
                -- Fetch business label from Config.Businesses
                local businessData = Config.Businesses[availability.business_id]
                local businessLabel = businessData and businessData.label or availability.business_id
                local icon = businessData and businessData.icon or 'fa-calendar'

                -- Ensure timestamps are sent from the server in human-readable format
                local formattedFrom = availability.formatted_from or "Unknown"
                local formattedTo = availability.formatted_to or "Unknown"

                table.insert(options, {
                    title = ('%s - Availability'):format(businessLabel),
                    description = ('📅 **From:** %s\n📅 **To:** %s\n📝 **Notes:** %s'):format(
                        formattedFrom, formattedTo, availability.notes or 'None'
                    ),
                    icon = icon,
                    onSelect = function()
                        OpenEditAvailabilityMenu(availability)
                    end
                })
            end
        end

        -- Register & Open the menu dynamically
        lib.registerContext({
            id = 'existing_availability_menu',
            title = 'Existing Availability',
            options = options
        })

        lib.showContext('existing_availability_menu')
    end)
end

function OpenEditAvailabilityMenu(availability)
    local options = {
        {
            title = '✏️ Edit Availability',
            description = 'Modify the date, time, or notes.',
            onSelect = function()
                EditAvailabilityDialog(availability)
            end
        },
        {
            title = '🗑️ Delete Availability',
            description = 'Remove this availability entry.',
            onSelect = function()
                ConfirmDeleteAvailability(availability.id)
            end
        }
    }

    local businessLabel = Config.Businesses[availability.business_id] and Config.Businesses[availability.business_id].label or availability.business_id
    lib.registerContext({
        id = 'edit_availability_menu',
        title = ('Edit: %s'):format(businessLabel),
        options = options
    })

    lib.showContext('edit_availability_menu')
end

function ConfirmDeleteAvailability(availabilityId)
    local confirm = lib.alertDialog({
        header = 'Confirm Deletion',
        content = 'Are you sure you want to delete this availability entry?',
        centered = true,
        cancel = true
    })

    if confirm == "confirm" then
        TriggerServerEvent('cr-bookings:server:deleteAvailability', availabilityId)
    end
end

function EditAvailabilityDialog(availability)
    if not availability then return end

    if Config.DebugMode then
        print(json.encode(availability))
    end

    -- Open the input dialog
    local businessLabel = Config.Businesses[availability.business_id] and Config.Businesses[availability.business_id].label or availability.business_id
    local input = lib.inputDialog(('Edit Availability - %s'):format(businessLabel), {
        { -- Display the business name (Read-only)
            type = 'input',
            label = 'Business',
            default = businessLabel,
            disabled = true
        },
        { -- Date selection
            type = 'date',
            label = 'Date',
            format = 'DD/MM/YYYY',
            default = availability.start_time * 1000, -- Expecting milliseconds (JS standard)
            returnString = true,
            required = true
        },
        { -- From Hour
            type = 'slider',
            label = 'From Hour',
            min = 0,
            max = 23,
            default = tonumber(availability.formatted_from:sub(12, 13)),
            required = true
        },
        { -- From Minute
            type = 'slider',
            label = 'From Minute',
            min = 0,
            max = 59,
            step = 10,
            default = tonumber(availability.formatted_from:sub(15, 16)),
            required = true
        },
        { -- To Hour
            type = 'slider',
            label = 'To Hour',
            min = 0,
            max = 23,
            default = tonumber(availability.formatted_to:sub(12, 13)),
            required = true
        },
        { -- To Minute
            type = 'slider',
            label = 'To Minute',
            min = 0,
            max = 59,
            step = 10,
            default = tonumber(availability.formatted_to:sub(15, 16)),
            required = true
        },
        { -- Notes field
            type = 'textarea',
            label = 'Notes',
            default = availability.notes or '',
            required = false
        }
    })

    -- If the user cancels, exit
    if not input then return end

    -- Extract and parse new values
    local updatedData = {
        id = availability.id,
        business_id = availability.business_id,
        date = input[2], -- Selected Date (DD/MM/YYYY)
        fromHour = tonumber(input[3]),
        fromMin = tonumber(input[4]),
        toHour = tonumber(input[5]),
        toMin = tonumber(input[6]),
        notes = input[7] or ""
    }

    -- Validate that start time is before end time
    local fromTime = updatedData.fromHour * 60 + updatedData.fromMin
    local toTime = updatedData.toHour * 60 + updatedData.toMin

    if fromTime >= toTime then
        TriggerEvent('ox_lib:notify', {
            title = 'Invalid Availability',
            type = 'error',
            position = 'bottom',
            duration = 5000,
            description = 'Start time must be before end time.',
            icon = 'ban',
            iconColor = '#C53030'
        })
        return
    end

    -- Confirm before updating
    local confirm = lib.alertDialog({
        header = 'Confirm Changes',
        content = ('Are you sure you want to update your availability for **%s**?\n\n📅 **Date:** %s\n🕒 **From:** %02d:%02d\n🕒 **To:** %02d:%02d\n📝 **Notes:** %s'):format(
            updatedData.business_id, updatedData.date, updatedData.fromHour, updatedData.fromMin, updatedData.toHour, updatedData.toMin, updatedData.notes or 'None'
        ),
        centered = true,
        cancel = true
    })

    if confirm ~= 'confirm' then return end

    -- Send updated data as a table
    TriggerServerEvent('cr-bookings:server:updateAvailability', updatedData)

    -- Notify user
    TriggerEvent('ox_lib:notify', {
        title = 'Availability Updated',
        type = 'success',
        position = 'bottom',
        duration = 5000,
        description = 'Your availability has been successfully updated.',
        icon = 'check-circle',
        iconColor = '#28A745'
    })
end