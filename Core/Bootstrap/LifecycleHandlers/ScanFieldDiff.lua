local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Did a BN scan change a conversation's card? Capture before the scan writes,
-- Changed after. Only plain (non-table) fields count.
local ScanFieldDiff = {}

-- Tracked fields of the conversation last captured; one reused table, so the
-- check allocates nothing per friend.
local scanBefore = {}

-- lastSeenAt is re-stamped on every scan of a watched online friend, but only
-- the open window's header shows it, so it never marks a closed-window card.
local UNTRACKED_FIELDS = { lastSeenAt = true }

local function isTracked(field, value)
  return type(value) ~= "table" and not UNTRACKED_FIELDS[field]
end

function ScanFieldDiff.Capture(conversation)
  for field in pairs(scanBefore) do
    scanBefore[field] = nil
  end
  for field, value in pairs(conversation) do
    if isTracked(field, value) then
      scanBefore[field] = value
    end
  end
end

function ScanFieldDiff.Changed(conversation)
  for field, value in pairs(conversation) do
    if isTracked(field, value) and scanBefore[field] ~= value then
      return true
    end
  end
  for field in pairs(scanBefore) do
    if conversation[field] == nil then
      return true
    end
  end
  return false
end

ns.BootstrapLifecycleHandlersScanFieldDiff = ScanFieldDiff
return ScanFieldDiff
