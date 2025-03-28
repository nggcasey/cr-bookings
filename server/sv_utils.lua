--- Converts date and time into a Unix timestamp
---@param day number Day of the month (1-31)
---@param month number Month (1-12)
---@param year number Full year (e.g., 2025)
---@param hour number Hour of the day (0-23)
---@param min number Minute of the hour (0-59)
---@param sec? number Second of the minute (0-59), defaults to 0
---@return number Unix timestamp
function ConvertToUnixTimestamp(day, month, year, hour, min, sec)
    sec = sec or 0 -- default seconds to 0 if not provided

    local timestamp = os.time({
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec
    })

    return timestamp
end

--- Converts a Unix timestamp into a human-readable date format (DD/MM/YYYY HH:MM)
---@param timestamp number Unix timestamp to convert
---@return string Formatted date string
function ConvertUnixToReadable(timestamp)
    return os.date("%d/%m/%Y %H:%M", timestamp)
end


--Check for availability conflicts in database
function CheckAvailabilityIssues(staff_cid, business_id, start, end_time, excludeId)
    local sql = [[
        SELECT id, business_id FROM cr_bookings
        WHERE staff_cid = ?
        AND id != ? -- Exclude current entry if updating
        AND (
            (start_time <= ? AND end_time >= ?) OR
            (start_time <= ? AND end_time >= ?) OR
            (start_time >= ? AND end_time <= ?)
        )
        LIMIT 1
    ]]

    local results = MySQL.query.await(sql, {
        staff_cid,
        excludeId or 0,
        start, start,
        end_time, end_time,
        start, end_time
    })

    if results and #results > 0 then
        for _, entry in ipairs(results) do
            if entry.business_id == business_id then
                -- Conflict: Same business, prevents creation
                return "conflict", entry.id
            else
                -- Overlap: Different business, warns the user
                return "overlap", entry.id
            end
        end
    end

    return nil, nil -- No conflicts or overlaps
end

--- Convert a "DD/MM/YYYY" string into midnight Unix timestamps for that day
function GetDayBoundaries(dateStr)
    if Config.DebugMode then
        print("[DEBUG] GetDayBoundaries - Received Date:", dateStr)
    end

    local d, m, y = dateStr:match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
    if not d or not m or not y then
        print("[ERROR] GetDayBoundaries - Invalid date format:", dateStr)
        return nil, nil
    end

    local dayStart = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0, min = 0, sec = 0 })
    local dayEnd   = dayStart + 86400 -- 24 hours later

    if Config.DebugMode then
        print("[DEBUG] GetDayBoundaries - dayStart:", dayStart, " | dayEnd:", dayEnd)
    end

    return dayStart, dayEnd
end



--- Convert a Unix timestamp to "minutes from midnight" relative to dayStart
local function TimestampToMinutes(ts, dayStart)
    return math.floor((ts - dayStart) / 60)
end

--- Return free/busy intervals for a given staff & day
-- function ComputeFreeBusyBlocks(staffCid, dateStr)
--     -- Convert date string into UNIX timestamps (start and end of the day)
--     local dayStart, dayEnd = GetDayBoundaries(dateStr)

--     if Config.DebugMode then
--         print("[DEBUG] ComputeFreeBusyBlocks - Processing Staff:", staffCid, "| Date:", dateStr)
--         print("[DEBUG] ComputeFreeBusyBlocks - Day Start:", dayStart, "| Day End:", dayEnd)
--     end

--     -- Fetch availability for the staff member
--     local avQuery = [[
--         SELECT start_time, end_time
--         FROM cr_bookings
--         WHERE staff_cid = ?
--           AND entry_type = 'availability'
--           AND end_time > ?
--           AND start_time < ?
--     ]]
--     local avResults = MySQL.query.await(avQuery, { staffCid, dayStart, dayEnd })

--     if Config.DebugMode then
--         print("[DEBUG] ComputeFreeBusyBlocks - Raw Availability Results:", json.encode(avResults))
--     end

--     -- If no availability exists, return empty
--     if not avResults or #avResults == 0 then
--         return {}
--     end

--     -- Process availability into time blocks
--     local availability = {}
--     for _, row in ipairs(avResults) do
--         local avStart = math.max(row.start_time, dayStart) -- Ensure it's within day bounds
--         local avEnd = math.min(row.end_time, dayEnd) -- Ensure it's within day bounds

--         -- Convert to minute-based time slots
--         table.insert(availability, {
--             startTime = math.floor((avStart - dayStart) / 60),
--             endTime   = math.floor((avEnd - dayStart) / 60),
--             type = "free"
--         })
--     end

--     if Config.DebugMode then
--         print("[DEBUG] ComputeFreeBusyBlocks - Processed Free Blocks:", json.encode(availability))
--     end

--     return availability
-- end




