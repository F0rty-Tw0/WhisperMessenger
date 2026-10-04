local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- The "Blocked N this session" line under each Filters page row.
local BlockedCount = {}

local MAX_EXACT = 999

function BlockedCount.Format(count)
  count = count or 0
  if count > MAX_EXACT then
    return MAX_EXACT .. "+"
  end
  return tostring(count)
end

function BlockedCount.Text(count)
  return string.format(Localization.Text("Blocked %s this session"), BlockedCount.Format(count))
end

ns.FiltersSettingsBlockedCount = BlockedCount
return BlockedCount
