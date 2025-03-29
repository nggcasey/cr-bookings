------------------
--CALLBACKS
------------------

--Returns Players Availability
lib.callback.register('cr-bookings:server:getMyAvailability', function(source)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return {} end

    local citizenid = player.PlayerData.citizenid

    local query = [[
        SELECT id, business_id, start_time, end_time, notes
        FROM cr_bookings
        WHERE staff_cid = ?
          AND entry_type = 'availability'
          AND end_time > UNIX_TIMESTAMP()

        ORDER BY start_time ASC
    ]]

    local results = MySQL.query.await(query, { citizenid })

    if not results or #results == 0 then return {} end

    -- Format timestamps before sending data to the client
    for _, entry in pairs(results) do
        entry.formatted_from = ConvertUnixToReadable(entry.start_time)
        entry.formatted_to = ConvertUnixToReadable(entry.end_time)
    end

    return results
end)

-- Fetch available staff for a selected business
lib.callback.register('cr-bookings:server:getAvailableStaff', function(source, businessKey)
    local query = [[
        SELECT DISTINCT staff_cid, charinfo
        FROM cr_bookings
        JOIN players ON cr_bookings.staff_cid = players.citizenid
        WHERE business_id = ? AND entry_type = 'availability' AND end_time > UNIX_TIMESTAMP()
    ]]

    local results = MySQL.query.await(query, { businessKey })
    local staffList = {}

    for _, row in ipairs(results or {}) do
        local charinfo = json.decode(row.charinfo or '{}')
        local fullName = (charinfo.firstname or 'Unknown') .. ' ' .. (charinfo.lastname or 'Unknown')
        table.insert(staffList, { value = row.staff_cid, label = (fullName .. " (" .. row.staff_cid .. ")") })
    end

    return staffList
end)

-- Fetch available days for selected staff members or all staff in a business
lib.callback.register('cr-bookings:server:getAvailableDays', function(source, businessKey, selectedStaff)
    -- 1. Validate data from the client
    if not source then
        print('[Callback Error] - "cr-bookings:server:getAvailableDays" - No source received')
        return
    end

    if not businessKey then
        print('[Callback Error] - "cr-bookings:server:getAvailableDays" - No business key received')
        return
    end

    businessKey = tostring(businessKey)

    -- 2. Build the base query for distinct available days along with their UNIX timestamp
    local query = [[
        SELECT DISTINCT
            FROM_UNIXTIME(start_time, '%D %M %Y') AS available_day,
            UNIX_TIMESTAMP(DATE(FROM_UNIXTIME(start_time))) AS day_timestamp
        FROM cr_bookings
        WHERE entry_type = 'availability'
          AND business_id = ?
          AND end_time > UNIX_TIMESTAMP()
        ORDER BY start_time
    ]]

    local params = { businessKey }

    -- 3. Append staff condition if a staff member is selected
    if selectedStaff then
        selectedStaff = tostring(selectedStaff)
        query = query .. [[ AND staff_cid = ? ]]
        table.insert(params, selectedStaff)
    end

    -- 4. Execute the query and build the list of days
    local results = MySQL.query.await(query, params)
    local daysList = {}

    for _, row in ipairs(results) do
        table.insert(daysList, {
            formatted_day = row.available_day,  -- "2nd March 2025"
            timestamp = row.day_timestamp       -- 1740787200 (00:00:00 UTC of that day)
        })
    end

    return daysList
end)

lib.callback.register('cr-bookings:server:getAvailabilitySlots', function(source, dayTimestamp, businessKey, staffId)
    if not dayTimestamp or not businessKey then
        print('[ERROR] Missing required parameters in getAvailabilitySlots')
        return {}
    end

    local params = { businessKey, dayTimestamp }

    -- Query to fetch availability slots, staff names, and formatted date
    local availabilityQuery = [[
        SELECT
            a.id,
            a.staff_cid,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.firstname')) AS first_name,
            JSON_UNQUOTE(JSON_EXTRACT(p.charinfo, '$.lastname')) AS last_name,
            DATE_FORMAT(FROM_UNIXTIME(a.start_time), '%H:%i') AS formatted_start,
            DATE_FORMAT(FROM_UNIXTIME(a.end_time), '%H:%i') AS formatted_end,
            DATE_FORMAT(FROM_UNIXTIME(a.start_time), '%D %M %Y') AS formatted_date,
            a.start_time,
            a.end_time
        FROM cr_bookings a
        LEFT JOIN players p ON a.staff_cid = p.citizenid
        WHERE a.business_id = ?
          AND a.entry_type = 'availability'
          AND DATE(FROM_UNIXTIME(a.start_time)) = DATE(FROM_UNIXTIME(?))
    ]]

    -- Add staff filtering if a specific staff member is selected
    if staffId then
        availabilityQuery = availabilityQuery .. " AND a.staff_cid = ?"
        table.insert(params, staffId)
    end

    local availabilityResults = MySQL.query.await(availabilityQuery, params) or {}

    if #availabilityResults == 0 then
        print("[INFO] No availability slots found for", businessKey, "on", os.date("%d %B %Y", dayTimestamp))
        return {}
    end

    local slots = {}

    -- Fetch booked appointments for each availability slot
    for _, slot in ipairs(availabilityResults) do
        local bookedAppointmentsQuery = [[
            SELECT
                DATE_FORMAT(FROM_UNIXTIME(start_time), '%H:%i') AS start_time,
                DATE_FORMAT(FROM_UNIXTIME(end_time), '%H:%i') AS end_time
            FROM cr_bookings
            WHERE business_id = ?
              AND entry_type = 'appointment'
              AND staff_cid = ?
              AND start_time >= ?
              AND end_time <= ?
        ]]

        local bookedAppointments = MySQL.query.await(bookedAppointmentsQuery, {
            businessKey, slot.staff_cid, slot.start_time, slot.end_time
        }) or {}

        table.insert(slots, {
            id = slot.id,
            staff_cid = slot.staff_cid,
            staff_name = (slot.first_name and slot.last_name) and (slot.first_name .. " " .. slot.last_name) or "Unknown Staff",
            formatted_start = slot.formatted_start,
            formatted_end = slot.formatted_end,
            formatted_date = slot.formatted_date,
            start_time = slot.start_time,
            end_time = slot.end_time,
            booked_appointments = bookedAppointments
        })
    end

    return slots
end)






--DEPRECATED
-- Fetch available time blocks for a particular day (optionally by staff member too)
lib.callback.register('cr-bookings:server:getDaySchedule', function(source, dayTimestamp, appointmentType, businessKey, staffId)
    if not dayTimestamp or not businessKey or not appointmentType then
        print('[ERROR] Missing required parameters in getDaySchedule')
        return {}
    end

    local duration = appointmentType.duration or 0
    local buffer = appointmentType.buffer or 0

    -- Retrieve business label from Config.Businesses
    local businessLabel = Config.Businesses[businessKey] and Config.Businesses[businessKey].label or 'Unknown Business'

    -- Base Query
    local query = [[
        WITH
        avail_blocks AS (
            SELECT
                staff_cid,
                DATE_FORMAT(FROM_UNIXTIME(start_time), '%H:%i') AS formatted_start,
                DATE_FORMAT(FROM_UNIXTIME(end_time), '%H:%i') AS formatted_end,
                start_time, end_time
            FROM cr_bookings
            WHERE business_id = ?
              AND entry_type = 'availability'
              AND DATE(FROM_UNIXTIME(start_time)) = DATE(FROM_UNIXTIME(?))
    ]]

    local params = { businessKey, dayTimestamp }

    -- Append staff condition if `staffId` is provided
    if staffId then
        query = query .. " AND staff_cid = ?"
        table.insert(params, staffId)
    end

    -- Continue with booked blocks
    query = query .. [[
        ),
        booked_blocks AS (
            SELECT
                staff_cid,
                DATE_FORMAT(FROM_UNIXTIME(start_time), '%H:%i') AS formatted_start,
                DATE_FORMAT(FROM_UNIXTIME(end_time), '%H:%i') AS formatted_end,
                start_time, end_time
            FROM cr_bookings
            WHERE business_id = ?
              AND entry_type = 'appointment'
              AND DATE(FROM_UNIXTIME(start_time)) = DATE(FROM_UNIXTIME(?))
    ]]

    table.insert(params, businessKey)
    table.insert(params, dayTimestamp)

    -- Append staff condition for booked blocks
    if staffId then
        query = query .. " AND staff_cid = ?"
        table.insert(params, staffId)
    end

    -- Finish the query with the main selection
    query = query .. [[
        )
        SELECT
            a.staff_cid, a.formatted_start, a.formatted_end,
            CASE
                WHEN b.start_time IS NOT NULL THEN 'busy'
                ELSE 'free'
            END AS block_type
        FROM avail_blocks a
        LEFT JOIN booked_blocks b
        ON (b.start_time >= a.start_time AND b.start_time < a.end_time)
        ORDER BY a.start_time;
    ]]

    -- Execute SQL Query
    local results = MySQL.query.await(query, params) or {}

    -- Process results to include staff names (check online first, then database)
    for _, block in ipairs(results) do
        local player = exports.qbx_core:GetPlayerByCitizenId(block.staff_cid)
        if player then
            -- Online Player
            block.staff_name = player.PlayerData.charinfo.firstname .. ' ' .. player.PlayerData.charinfo.lastname
        else
            -- Offline Player - Fetch from database
            local nameQuery = [[
                SELECT JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')) AS firstname,
                       JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')) AS lastname
                FROM players WHERE citizenid = ?
            ]]
            local nameResult = MySQL.query.await(nameQuery, { block.staff_cid })
            if nameResult and #nameResult > 0 then
                block.staff_name = nameResult[1].firstname .. ' ' .. nameResult[1].lastname
            else
                block.staff_name = 'Unknown'
            end
        end

        -- Attach business label
        block.business_label = businessLabel
    end

    return results -- Send directly to the client
end)

--Fetch available start times
lib.callback.register('cr-bookings:server:getAvailableStartTimes', function(source, dayTimestamp, businessKey, staffId)
    if not dayTimestamp or not businessKey then
        print('[ERROR] Missing required parameters in getAvailableStartTimes')
        return {}
    end

    -- Fetch existing bookings to prevent conflicts
    local query = [[
        SELECT
            DATE_FORMAT(FROM_UNIXTIME(start_time), '%H:%i') AS formatted_start,
            DATE_FORMAT(FROM_UNIXTIME(end_time), '%H:%i') AS formatted_end
        FROM cr_bookings
        WHERE business_id = ?
          AND entry_type = 'appointment'
          AND DATE(FROM_UNIXTIME(start_time)) = DATE(FROM_UNIXTIME(?))
          AND staff_cid = ?
    ]]
    local params = { businessKey, dayTimestamp, staffId }
    local results = MySQL.query.await(query, params) or {}

    return results
end)

--TODO: Review server side checks
--Checks: Security & stablility - Rate limiting? Queuing bookings?
lib.callback.register('cr-bookings:server:bookAppointment', function(source, dayTimestamp, appointmentType, businessKey, staffId, formattedTime, bookingNotes)
    if not dayTimestamp or not businessKey or not appointmentType or not formattedTime or not staffId then
        print('[ERROR] Missing required parameters in bookAppointment')
        return false
    end

    local duration = appointmentType.duration or 0
    local buffer = appointmentType.buffer or 0
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end

    local citizenId = player.PlayerData.citizenid
    local startTimeQuery = MySQL.query.await("SELECT UNIX_TIMESTAMP(CONCAT(DATE(FROM_UNIXTIME(?)), ' ', ?)) AS start_time", { dayTimestamp, formattedTime })
    if not startTimeQuery[1] then return false end

    local startTime = startTimeQuery[1].start_time
    local endTime = startTime + (duration * 60) -- Base end time without buffer
    local bufferedEndTime = endTime + (buffer * 60) -- Full end time with buffer

    if Config.DebugMode then
        print('[DEBUG] Booking Attempt: staffId=' .. staffId .. ', startTime=' .. startTime .. ' (' .. os.date('%H:%M', startTime) .. '), endTime=' .. bufferedEndTime .. ' (' .. os.date('%H:%M', bufferedEndTime) .. '), duration=' .. duration .. ', buffer=' .. buffer)
    end

    -- Check for booking conflicts across all businesses
    local hasConflict, conflictId = CheckBookingConflicts(staffId, startTime, endTime, buffer)
    if hasConflict then
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Staff is already booked elsewhere during this time. Conflict ID: ' .. tostring(conflictId)
        })
        return false
    end

    -- Check if within staff availability for this business
    local avIssueType, avConflictId = CheckAvailabilityIssues(staffId, businessKey, startTime, bufferedEndTime, nil, "availability")
    if not avIssueType then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'Staff is not available at this business during this time.' })
        return false
    end

    -- Ensure the appointment end time doesn’t exceed availability end time
    local availabilityQuery = [[
        SELECT end_time FROM cr_bookings
        WHERE staff_cid = ? AND business_id = ? AND entry_type = 'availability'
          AND start_time <= ? AND end_time >= ?
        LIMIT 1
    ]]
    local availability = MySQL.query.await(availabilityQuery, { staffId, businessKey, startTime, startTime })
    if not availability or #availability == 0 then
        TriggerClientEvent('ox_lib:notify', source, { type = 'error', description = 'No matching availability found for this start time.' })
        return false
    end

    local availabilityEndTime = availability[1].end_time
    if bufferedEndTime > availabilityEndTime then
        if Config.DebugMode then
            print('[DEBUG] Appointment rejected: bufferedEndTime=' .. bufferedEndTime .. ' (' .. os.date('%H:%M', bufferedEndTime) .. ') exceeds availabilityEndTime=' .. availabilityEndTime .. ' (' .. os.date('%H:%M', availabilityEndTime) .. ')')
        end
        TriggerClientEvent('ox_lib:notify', source, {
            type = 'error',
            description = 'Appointment duration exceeds staff availability (ends at ' .. os.date('%H:%M', availabilityEndTime) .. ').'
        })
        return false
    end

    -- Insert appointment
    local insertQuery = [[
        INSERT INTO cr_bookings (business_id, staff_cid, booked_by, entry_type, start_time, end_time, notes)
        VALUES (?, ?, ?, 'appointment', ?, ?, ?)
    ]]
    local result = MySQL.insert.await(insertQuery, { businessKey, staffId, citizenId, startTime, bufferedEndTime, bookingNotes })
    if result then
        TriggerClientEvent('ox_lib:notify', source, { type = 'success', description = 'Your appointment has been booked!' })
        return true
    else
        print("[ERROR] Failed to insert appointment into database")
        return false
    end
end)

------------------
--EVENTS
------------------

--Set Availability
RegisterNetEvent('cr-bookings:server:setAvailability', function(data)
    local src = source

    -- 1. Error handling: Ensure source exists
    if not src then return end

    -- 2. Fetch Player Data
    local player = exports.qbx_core:GetPlayer(src)
    local staff_cid = player and player.PlayerData and player.PlayerData.citizenid or nil

    -- 3. Error handling: Ensure player and citizen ID exist
    if not staff_cid then
        print('ERROR: Player or CitizenID could not be retrieved.')
        return
    end

    -- 4. Permission Check: Ensure the player is in the business
    local business_id = data.businessKey
    if not exports.qbx_core:HasGroup(src, business_id) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error: You are not part of this business',
            type = 'error',
            position = 'bottom',
            duration = 10000,
            description = 'If this is an error, please contact the server owner',
            icon = 'ban',
            iconColor = '#C53030'
        })
        return
    end

    -- 5. Convert Date & Time to Unix Timestamps
    local startTime = ConvertToUnixTimestamp(data.day, data.month, data.year, data.fromHour, data.fromMin)
    local endTime   = ConvertToUnixTimestamp(data.day, data.month, data.year, data.toHour, data.toMin)

    local currentTime = os.time() -- Get current server time

    -- 6. Time Validation: Ensure start time is in the future
    if startTime <= currentTime then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Invalid Availability',
            type = 'error',
            position = 'bottom',
            duration = 10000,
            description = 'You cannot set availability in the past!',
            icon = 'ban',
            iconColor = '#C53030'
        })

        if Config.Debug then
            print("ERROR: Cannot create availability in the past.")
        end

        return
    end

    -- 7. Time Validation & Conflict Checking: Start time must be before end time
    if startTime >= endTime then
        print("ERROR: Start time must be before end time.")
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Invalid Availability',
            type = 'error',
            position = 'bottom',
            duration = 10000,
            description = 'Start time must be before end time.',
            icon = 'ban',
            iconColor = '#C53030'
        })
        return
    end

    local issueType, conflictId = CheckAvailabilityIssues(staff_cid, business_id, startTime, endTime, existingAvailabilityId)

    if issueType == "conflict" then
        if Config.DebugMode then
            print("Error: Availability conflicts with an existing entry at the same business (ID: " .. conflictId .. ")")
        end

        -- Send an alert dialog to the player on the client side
        TriggerClientEvent('ox_lib:alertDialog', src, {
            header = 'Availability Conflict',
            content = 'You already have availability at this business during this time.\n\nPlease adjust your availability.',
            centered = true
        })

        return -- Prevents saving
    elseif issueType == "overlap" then
        if Config.DebugMode then
            print("Warning: Availability overlaps with another business (ID: " .. conflictId .. ")")
        end

        -- Send an alert dialog to the player on the client side
        TriggerClientEvent('ox_lib:alertDialog', src, {
            header = 'Availability Overlap',
            content = 'You have an overlapping availability during this time.\n\nPlease be mindful of this.',
            centered = true
        })

    end

    -- Proceed with saving availability
    if Config.DebugMode then
        print("Saving availability...")
    end

    -- 8. Insert Availability into Database
    local success, err = MySQL.insert.await("INSERT INTO cr_bookings (entry_type, business_id, staff_cid, start_time, end_time, notes) VALUES (?, ?, ?, ?, ?, ?)", {
        "availability", business_id, staff_cid, startTime, endTime, tostring(data.notes or "")
    })

    -- 9. Debugging & Error Logging
    if not success then
        print("[SQL ERROR] Failed to insert availability:", err)

        TriggerClientEvent('ox_lib:alertDialog', src{
            header = 'Failed to insert availability',
            content = 'Your availability could not be successfully saved, please try again later. If the issue persists, please report this as a bug to the development team',
            centered = true
        })

    else
        -- Convert timestamps to readable format
        local formattedStart = ConvertUnixToReadable(startTime)
        local formattedEnd = ConvertUnixToReadable(endTime)

        -- Fetch business label from config
        local businessLabel = Config.Businesses[business_id] and Config.Businesses[business_id].label or business_id

        -- Send a confirmation alert to the client
        TriggerClientEvent('ox_lib:alertDialog', src, {
            header = 'Availability Confirmed',
            content = ('Your availability has been successfully set for **%s**.\n🕒 **From:** %s\n🕒 **To:** %s\n📝 **Notes:** %s'):format(
                businessLabel, formattedStart, formattedEnd, data.notes or 'None'
            ),
            centered = true
        })

        if Config.DebugMode then
            print("[SQL SUCCESS] Availability added for business:", business_id)
        end
    end
end)

--Delete Availability
RegisterNetEvent('cr-bookings:server:deleteAvailability', function(availabilityId)

    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local staff_cid = player.PlayerData.citizenid
    if not staff_cid then
        print('ERROR: Player or CitizenID could not be retrieved.')
        return
    end

    local query = [[
        DELETE FROM cr_bookings
        WHERE id = ? AND staff_cid = ? AND entry_type = 'availability'
    ]]

    local success = MySQL.update.await(query, { availabilityId, staff_cid })

    if success and success > 0 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Availability Deleted',
            type = 'success',
            position = 'bottom',
            showDuration = true,
            duration = 5000,
            description = 'Your availability has been removed successfully.',
            icon = 'check-circle',
            iconColor = '#28A745'
        })
        if Config.DebugMode then
            print('[SUCCESS] Availability ID: '..availabilityId..' deleted')
        end
    else
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            type = 'error',
            position = 'bottom',
            showDuration = true,
            duration = 5000,
            description = 'Failed to delete availability. Try again later.',
            icon = 'times-circle',
            iconColor = '#FF0000'
        })

        print('[ERROR] Availability ID: '..availabilityId..' failed to delete')
    end
end)

--Update Availability
RegisterNetEvent('cr-bookings:server:updateAvailability', function(data)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end

    local staff_cid = player.PlayerData.citizenid
    if not staff_cid then
        print('[ERROR] Player or CitizenID could not be retrieved.')
        return
    end

    -- Convert date and time to Unix timestamps
    local day, month, year = data.date:match("(%d+)/(%d+)/(%d+)")
    day, month, year = tonumber(day), tonumber(month), tonumber(year)

    local startTime = ConvertToUnixTimestamp(day, month, year, data.fromHour, data.fromMin)
    local endTime = ConvertToUnixTimestamp(day, month, year, data.toHour, data.toMin)

    -- Validate that start time is before end time
    if startTime >= endTime then
        print('[ERROR] Start time must be before end time.')
        return
    end

    -- Update query
    local success, err = MySQL.update.await([[
        UPDATE cr_bookings
        SET start_time = ?, end_time = ?, notes = ?
        WHERE id = ? AND staff_cid = ? AND entry_type = 'availability'
    ]], { startTime, endTime, data.notes, data.id, staff_cid })

    if success and success > 0 then
        if Config.DebugMode then
            print(('[SUCCESS] Availability ID %s updated by %s'):format(data.id, staff_cid))
        end
    else
        print(('[ERROR] Failed to update Availability ID: %s for %s'):format(data.id, staff_cid))
    end
end)

-- RegisterNetEvent('cr-bookings:server:createBooking', function(staffCid, dateStr, startTime, businessId)
--     local src = source

--     -- Debug: Print received data
--     if Config.DebugMode then
--         print("[DEBUG] createBooking - Received dateStr:", dateStr, "| Business:", businessId)
--     end

--     -- Convert date format from YYYY-MM-DD to DD/MM/YYYY
--     local y, m, d = dateStr:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
--     if y and m and d then
--         dateStr = ("%s/%s/%s"):format(d, m, y)
--     end

--     if Config.DebugMode then
--         print("[DEBUG] createBooking - Reformatted dateStr:", dateStr)
--     end

--     -- Get boundaries for the day
--     local dayStart, _ = GetDayBoundaries(dateStr)

--     -- Check if dayStart is nil
--     if not dayStart then
--         print("[ERROR] createBooking - Failed to get dayStart for date:", dateStr)
--         TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Invalid booking date. Please try again.' })
--         return
--     end

--     -- Convert start time to UNIX timestamp
--     local startTimeUnix = dayStart + (startTime * 60)
--     local endTimeUnix = startTimeUnix + (30 * 60) -- Default: 30 min booking

--     -- Debugging timestamps
--     if Config.DebugMode then
--         print("[DEBUG] createBooking - startTimeUnix:", startTimeUnix, "| endTimeUnix:", endTimeUnix)
--     end

--     -- Retrieve the player object from Qbox
--     local player = exports.qbx_core:GetPlayer(src)

--     if not player then
--         print("[ERROR] createBooking - Could not retrieve player object for:", src)
--         TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'Failed to process booking. Try again later.' })
--         return
--     end

--     local citizenId = player.PlayerData.citizenid

--     if Config.DebugMode then
--         print("[DEBUG] createBooking - Player Citizen ID:", citizenId)
--     end

--     -- Check for conflicts
--     local conflictQuery = [[
--         SELECT id FROM cr_bookings
--         WHERE staff_cid = ? AND entry_type = 'booking'
--           AND start_time < ? AND end_time > ?
--         LIMIT 1
--     ]]
--     local conflict = MySQL.query.await(conflictQuery, { staffCid, endTimeUnix, startTimeUnix })

--     if conflict and #conflict > 0 then
--         TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = 'This time slot is no longer available.' })
--         return
--     end

--     -- Insert the new booking with correct business ID and attendee
--     local insertQuery = [[
--         INSERT INTO cr_bookings (entry_type, business_id, staff_cid, start_time, end_time, attendees)
--         VALUES ('booking', ?, ?, ?, ?, ?)
--     ]]
--     MySQL.query.await(insertQuery, { businessId, staffCid, startTimeUnix, endTimeUnix, json.encode({ citizenId }) })

--     -- Notify user
--     TriggerClientEvent('ox_lib:notify', src, { type = 'success', description = 'Booking successfully created!' })
-- end)




