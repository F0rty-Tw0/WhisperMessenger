local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local MYTHIC_KEYSTONE_DIFFICULTY = 8
local MYTHIC_RAID_DIFFICULTY = 16

local ContentDetector = {}

function ContentDetector.IsMythicRestricted(getInstanceInfo)
  if type(getInstanceInfo) ~= "function" then
    return false
  end
  local _, _, difficultyID = getInstanceInfo()
  return difficultyID == MYTHIC_KEYSTONE_DIFFICULTY or difficultyID == MYTHIC_RAID_DIFFICULTY
end

ns.ContentDetector = ContentDetector
return ContentDetector
