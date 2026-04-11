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
  local _, instanceType, difficultyID = getInstanceInfo()
  if instanceType == "pvp" or instanceType == "arena" then
    return true
  end
  return difficultyID == MYTHIC_KEYSTONE_DIFFICULTY
end

ns.ContentDetector = ContentDetector
return ContentDetector
