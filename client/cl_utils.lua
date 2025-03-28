-- ==========================================
-- 🛠️ Utility Functions for Time Handling
-- ==========================================

-- Converts hours & minutes to milliseconds
function msTime(hour, minute)
    return (hour * 3600000) + (minute * 60000)
end

-- Extracts time components from a formatted time string (e.g., "10:30 PM" → 22,30)
function ExtractTime(formattedTime)
    local hour, min, period = formattedTime:match("(%d+):(%d+) (%a+)")
    hour, min = tonumber(hour), tonumber(min)

    -- Convert 12-hour format to 24-hour format
    if period == "PM" and hour ~= 12 then
        hour = hour + 12
    elseif period == "AM" and hour == 12 then
        hour = 0
    end

    return hour, min
end

-- ==========================================
-- 🌍 UTC OFFSET & TIME CONVERSIONS
-- ==========================================

-- Get current UTC offset in seconds using FiveM natives
function GetClientUtcOffsetInSeconds()
    local yLocal, moLocal, dLocal, hLocal, miLocal, sLocal = GetLocalTime()
    local yUtc, moUtc, dUtc, hUtc, miUtc, sUtc = GetUtcTime()

    local localSeconds = (hLocal * 3600) + (miLocal * 60) + sLocal
    local utcSeconds = (hUtc * 3600) + (miUtc * 60) + sUtc

    return localSeconds - utcSeconds  -- Returns offset in **seconds** (can be negative)
end

-- Formats UTC offset in hours & minutes (e.g., "+11:00" or "-05:30")
function GetFormattedUtcOffset()
    local offsetSeconds = GetClientUtcOffsetInSeconds()
    local hours = math.floor(math.abs(offsetSeconds) / 3600)
    local minutes = math.floor((math.abs(offsetSeconds) % 3600) / 60)

    local sign = (offsetSeconds >= 0) and "+" or "-"
    return string.format("%s%02d:%02d", sign, hours, minutes)
end

-- Converts a given Local Time to UTC using the calculated offset
function ConvertToUtc(year, month, day, hour, minute)
    local offsetSec = GetClientUtcOffsetInSeconds()

    -- Convert local time by subtracting offset
    local utcHour = hour - math.floor(offsetSec / 3600)
    local utcMinute = minute - math.floor((offsetSec % 3600) / 60)

    -- Handle minute rollovers
    if utcMinute < 0 then
        utcMinute = utcMinute + 60
        utcHour = utcHour - 1
    elseif utcMinute >= 60 then
        utcMinute = utcMinute - 60
        utcHour = utcHour + 1
    end

    -- Handle hour rollovers (e.g., going past midnight)
    if utcHour < 0 then
        utcHour = utcHour + 24
        day = day - 1
    elseif utcHour >= 24 then
        utcHour = utcHour - 24
        day = day + 1
    end

    return string.format("%02d-%02d-%04d %02d:%02d:00", day, month, year, utcHour, utcMinute)
end

-- Converts a "DD-MM-YYYY HH:MM:SS" UTC string to local time, returning "DD-MM-YYYY HH:MM:SS" local.
function ConvertUtcStringToLocal(utcString)
    -- Parse "DD-MM-YYYY HH:MM:SS"
    local d, mo, y, hh, mi, ss = utcString:match("^(%d%d)%-(%d%d)%-(%d%d%d%d) (%d%d):(%d%d):(%d%d)$")
    if not d then
        print("[WARNING] ConvertUtcStringToLocal could not parse:", utcString)
        return utcString -- Fallback; just return original
    end

    -- Convert them to numbers
    local day   = tonumber(d)
    local month = tonumber(mo)
    local year  = tonumber(y)
    local hour  = tonumber(hh)
    local min   = tonumber(mi)
    local sec   = tonumber(ss)

    -- Get the client’s UTC offset in seconds
    local offsetSec = GetClientUtcOffsetInSeconds()
    local offsetHours  = math.floor(offsetSec / 3600)
    local offsetMins   = math.floor((offsetSec % 3600) / 60)

    -- Apply offset to hour/minute
    hour = hour + offsetHours
    min  = min + offsetMins

    -- Handle minute rollovers
    if min >= 60 then
        min = min - 60
        hour = hour + 1
    elseif min < 0 then
        min = min + 60
        hour = hour - 1
    end

    -- Handle hour rollovers
    if hour >= 24 then
        hour = hour - 24
        day = day + 1
    elseif hour < 0 then
        hour = hour + 24
        day = day - 1
    end

    -- (Optional) handle day/month/year rollovers if crossing month boundaries
    -- For simplicity, we skip advanced date logic here.
    -- If you need it, you’d detect day > daysInMonth etc.

    -- Return new local time string
    return string.format("%02d-%02d-%04d %02d:%02d:%02d", day, month, year, hour, min, sec)
end


-- ==========================================
-- ⏳ FORMATTING FUNCTIONS
-- ==========================================

-- Fetch current Local & UTC time using FiveM natives (formatted as "DD-MM-YYYY HH:MM:SS")
function GetFormattedLocalAndUtcTime()
    local yLocal, moLocal, dLocal, hLocal, miLocal, sLocal = GetLocalTime()
    local yUtc, moUtc, dUtc, hUtc, miUtc, sUtc = GetUtcTime()

    local localTimeStr = string.format("%02d-%02d-%04d %02d:%02d:%02d", dLocal, moLocal, yLocal, hLocal, miLocal, sLocal)
    local utcTimeStr = string.format("%02d-%02d-%04d %02d:%02d:%02d", dUtc, moUtc, yUtc, hUtc, miUtc, sUtc)

    return localTimeStr, utcTimeStr
end

-- Parses a date string in "DD/MM/YYYY" format and returns day, month, year as numbers
function ParseDateString(dateStr)
    local d, m, y = dateStr:match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
    if d and m and y then
        return tonumber(d), tonumber(m), tonumber(y)
    else
        print("[ERROR] Invalid date format. Expected DD/MM/YYYY but got: " .. tostring(dateStr))
        return nil, nil, nil
    end
end







































-- -- Utility function to convert hours & minutes to milliseconds
-- function msTime(hour, minute)
--     return (hour * 3600000) + (minute * 60000)
-- end

-- -- Utility function to extract time from formatted timestamps
-- function ExtractTime(formattedTime)
--     local hour, min, period = formattedTime:match("(%d+):(%d+) (%a+)")
--     hour, min = tonumber(hour), tonumber(min)

--     -- Convert PM times to 24-hour format
--     if period == "PM" and hour ~= 12 then
--         hour = hour + 12
--     elseif period == "AM" and hour == 12 then
--         hour = 0
--     end

--     return hour, min
-- end

-- -- Get current UTC offset in seconds
-- function GetClientUtcOffsetInSeconds()
--     local yLocal, moLocal, dLocal, hLocal, miLocal, sLocal = GetLocalTime()
--     local yUtc, moUtc, dUtc, hUtc, miUtc, sUtc = GetUtcTime()

--     local localSeconds = (hLocal * 3600) + (miLocal * 60) + sLocal
--     local utcSeconds = (hUtc * 3600) + (miUtc * 60) + sUtc

--     return localSeconds - utcSeconds  -- Offset in seconds
-- end

-- -- Format the UTC offset in hours & minutes (e.g., "+11:00" or "-05:30")
-- function GetFormattedUtcOffset()
--     local offsetSeconds = GetClientUtcOffsetInSeconds()
--     local hours = math.floor(offsetSeconds / 3600)
--     local minutes = math.abs(math.floor((offsetSeconds % 3600) / 60))
--     return string.format("%+02d:%02d", hours, minutes)
-- end


-- -- Convert local time to UTC using calculated offset
-- function ConvertToUtc(year, month, day, hour, minute)
--     local offsetSec = GetClientUtcOffsetInSeconds()
--     local localTime = os.time({year = year, month = month, day = day, hour = hour, min = minute})
--     local utcTime = localTime - offsetSec
--     return os.date("%Y-%m-%d %H:%M:%S", utcTime)  -- Format for display
-- end

-- -- Display current local and UTC time for reference
-- function GetFormattedLocalAndUtcTime()
--     local yLocal, moLocal, dLocal, hLocal, miLocal, sLocal = GetLocalTime()
--     local yUtc, moUtc, dUtc, hUtc, miUtc, sUtc = GetUtcTime()

--     local localTimeStr = string.format("%02d-%02d-%04d %02d:%02d:%02d", dLocal, moLocal, yLocal, hLocal, miLocal, sLocal)
--     local utcTimeStr = string.format("%02d-%02d-%04d %02d:%02d:%02d", dUtc, moUtc, yUtc, hUtc, miUtc, sUtc)

--     return localTimeStr, utcTimeStr
-- end

-- -- Parses a date string in the format "DD/MM/YYYY" and returns day, month, year as numbers
-- function ParseDateString(dateStr)
--     local d, m, y = dateStr:match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
--     if d and m and y then
--         return tonumber(d), tonumber(m), tonumber(y)
--     else
--         print("[ERROR] Invalid date format. Expected DD/MM/YYYY but got: " .. tostring(dateStr))
--         return nil, nil, nil
--     end
-- end

