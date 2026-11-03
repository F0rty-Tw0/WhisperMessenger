local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SeenLevel = ns.SeenLevel or require("WhisperMessenger.Model.SeenLevel")
local WhoRow = ns.WhoRow or require("WhisperMessenger.Core.WhoRow")

-- Gathers the highest level per name from a /who reply, so SeenLevelEvents
-- walks the saved chats once per reply instead of once per row.
local WhoLevels = {}

-- Runs under pcall: comparing a 12.0 secret level throws. Any system line
-- inside the who window lands here; only the reply's own row counts, so an
-- unrelated line neither walks the store nor re-applies an older reply.
function WhoLevels.Collect(levels, info, systemText)
  if systemText ~= nil and not WhoRow.Matches(systemText, info) then
    return
  end
  local level = info.level
  if type(level) ~= "number" or level <= 0 then
    return
  end
  local nameKey = SeenLevel.NameKey(info.fullName)
  if nameKey ~= nil and (levels[nameKey] == nil or levels[nameKey] < level) then
    levels[nameKey] = level
  end
end

ns.SeenLevelEventsWhoLevels = WhoLevels
return WhoLevels
