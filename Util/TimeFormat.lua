local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TimeFormat = {}

local floor = math.floor

--- Returns current epoch seconds (WoW global)
local function now()
  return time()
end

--- Format a timestamp as "12:34 PM" for inside message bubbles
function TimeFormat.MessageTime(timestamp)
  if not timestamp or timestamp == 0 then return "" end
  return date("%I:%M %p", timestamp)
end

--- Format a timestamp as "March 18, 2026" for date separators
function TimeFormat.DateSeparator(timestamp)
  if not timestamp or timestamp == 0 then return "" end
  return date("%B %d, %Y", timestamp)
end

--- Format a timestamp as a short relative string for contact row timestamps.
--- Returns: "now", "2m", "1h", "Yesterday", "Mon", "Mar 14"
function TimeFormat.ContactPreview(timestamp)
  if not timestamp or timestamp == 0 then return "" end
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
    return date("%a", timestamp)
  end
  -- Older: show "Mar 14"
  return date("%b %d", timestamp)
end

--- Format a longer relative string for status lines.
--- Returns: "just now", "2 minutes ago", "1 hour ago", "yesterday", "Mar 14, 2026"
function TimeFormat.Relative(timestamp)
  if not timestamp or timestamp == 0 then return "unknown" end
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
  return date("%b %d, %Y", timestamp)
end

--- Check if two timestamps are on different calendar days
function TimeFormat.IsDifferentDay(ts1, ts2)
  if not ts1 or not ts2 or ts1 == 0 or ts2 == 0 then return true end
  local day1 = floor(ts1 / 86400)
  local day2 = floor(ts2 / 86400)
  return day1 ~= day2
end

ns.TimeFormat = TimeFormat

return TimeFormat
