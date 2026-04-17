local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TimeFormat = {}

local floor = math.floor

local VALID_FORMATS = { ["12h"] = true, ["24h"] = true }
local VALID_SOURCES = { ["local"] = true, ["server"] = true }

local config = {
  timeFormat = "12h",
  timeSource = "local",
}

local serverOffset = nil

--- Compute the display offset between server time and local time.
--- Uses C_DateAndTime.GetCurrentCalendarTime when available.
local function computeServerOffset()
  if not _G.C_DateAndTime or not _G.C_DateAndTime.GetCurrentCalendarTime then
    return 0
  end
  local sCal = _G.C_DateAndTime.GetCurrentCalendarTime()
  local lt = date("*t")
  local sEpoch = time({
    year = sCal.year,
    month = sCal.month,
    day = sCal.monthDay,
    hour = sCal.hour,
    min = sCal.minute,
    sec = sCal.second or 0,
    isdst = lt.isdst,
  })
  local lEpoch = time(lt)
  local raw = sEpoch - lEpoch
  return floor(raw / 900 + 0.5) * 900
end

--- Adjust a timestamp for display in the configured time source.
--- When source is "server", shifts the timestamp so that date() output
--- reflects the server's calendar day and time.
local function displayTimestamp(ts)
  if config.timeSource ~= "server" then
    return ts
  end
  if serverOffset == nil then
    serverOffset = computeServerOffset()
  end
  return ts + serverOffset
end

--- Configure time format and source.
--- Accepts a table with optional keys: timeFormat ("12h"|"24h"), timeSource ("local"|"server").
--- Invalid values are silently ignored.
function TimeFormat.Configure(opts)
  if type(opts) ~= "table" then
    return
  end
  if opts.timeFormat and VALID_FORMATS[opts.timeFormat] then
    config.timeFormat = opts.timeFormat
  end
  if opts.timeSource and VALID_SOURCES[opts.timeSource] then
    config.timeSource = opts.timeSource
    serverOffset = nil -- reset cached offset on source change
  end
end

--- Returns a shallow copy of the current config.
function TimeFormat.GetConfig()
  return { timeFormat = config.timeFormat, timeSource = config.timeSource }
end

--- Returns current epoch seconds, respecting the configured time source.
local function now()
  if config.timeSource == "server" and _G.GetServerTime then
    return _G.GetServerTime()
  end
  return time()
end

--- Format a timestamp for inside message bubbles.
--- 12h: "2:30 PM", 24h: "14:30"
function TimeFormat.MessageTime(timestamp)
  if not timestamp or timestamp == 0 then
    return ""
  end
  local ts = displayTimestamp(timestamp)
  if config.timeFormat == "24h" then
    return date("%H:%M", ts)
  end
  return date("%I:%M %p", ts)
end

--- Format a timestamp as "March 18, 2026" for date separators.
--- Respects the configured time source.
function TimeFormat.DateSeparator(timestamp)
  if not timestamp or timestamp == 0 then
    return ""
  end
  return date("%B %d, %Y", displayTimestamp(timestamp))
end

--- Format a timestamp as a short relative string for contact row timestamps.
--- Returns: "now", "2m", "1h", "Yesterday", "Mon", "Mar 14"
function TimeFormat.ContactPreview(timestamp)
  if not timestamp or timestamp == 0 then
    return ""
  end
  local current = now()
  local diff = current - timestamp
  if diff < 60 then
    return "now"
  elseif diff < 3600 then
    return floor(diff / 60) .. "m"
  elseif diff < 86400 then
    return floor(diff / 3600) .. "h"
  end
  -- Check if yesterday
  local todayStart = current - (current % 86400)
  if timestamp >= todayStart - 86400 and timestamp < todayStart then
    return "Yesterday"
  end
  -- Within last 7 days: show day name
  if diff < 604800 then
    return date("%a", displayTimestamp(timestamp))
  end
  -- Older: show "Mar 14"
  return date("%b %d", displayTimestamp(timestamp))
end

--- Format a longer relative string for status lines.
--- Returns: "just now", "2 minutes ago", "1 hour ago", "yesterday", "Mar 14, 2026"
function TimeFormat.Relative(timestamp)
  if not timestamp or timestamp == 0 then
    return "unknown"
  end
  local current = now()
  local diff = current - timestamp
  if diff < 60 then
    return "just now"
  elseif diff < 3600 then
    local mins = floor(diff / 60)
    return mins .. (mins == 1 and " minute ago" or " minutes ago")
  elseif diff < 86400 then
    local hours = floor(diff / 3600)
    return hours .. (hours == 1 and " hour ago" or " hours ago")
  end
  local todayStart = current - (current % 86400)
  if timestamp >= todayStart - 86400 and timestamp < todayStart then
    return "yesterday"
  end
  return date("%b %d, %Y", displayTimestamp(timestamp))
end

--- Check if two timestamps are on different calendar days.
--- Respects the configured time source and local timezone.
function TimeFormat.IsDifferentDay(ts1, ts2)
  if not ts1 or not ts2 or ts1 == 0 or ts2 == 0 then
    return true
  end
  return date("%Y%m%d", displayTimestamp(ts1)) ~= date("%Y%m%d", displayTimestamp(ts2))
end

ns.TimeFormat = TimeFormat

return TimeFormat
