local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local MYTHIC_KEYSTONE_DIFFICULTY = 8

local ContentDetector = {}

function ContentDetector.IsMythicRestricted(getInstanceInfo)
  if type(getInstanceInfo) ~= "function" then
    return false
  end
  local _, _, difficultyID = getInstanceInfo()
  return difficultyID == MYTHIC_KEYSTONE_DIFFICULTY
end

function ContentDetector.IsCompetitiveContent(getInstanceInfo)
  if type(getInstanceInfo) ~= "function" then
    return false
  end
  local _, instanceType = getInstanceInfo()
  -- PvP (Battlegrounds) and Arenas are considered competitive content.
  -- In these zones, the messenger "soft-locks" (shows a notice and pauses).
  -- Our AutoOpenCoordinator is configured to NOT intercept whispers when
  -- this lock is active, allowing the default Blizzard chat to handle
  -- communications in these restricted environments.
  if instanceType == "pvp" or instanceType == "arena" then
    return true
  end

  -- Mythic+ is handled separately by IsMythicRestricted and the hard lockdown.
  return false
end

ns.ContentDetector = ContentDetector
return ContentDetector
