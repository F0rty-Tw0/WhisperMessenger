local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Maps the translated race name a /who row gives to the game's race tag
-- (Undead -> Scourge), which faction lookups need. A female or other form
-- the game's race list doesn't name gets no tag.
local RaceTags = {}

-- Race ids have gaps, so the scan never stops at the first missing one.
local MAX_RACE_ID = 100

---@type table|nil
local tagByName = nil

local function build()
  local map = {}
  local api = _G.C_CreatureInfo
  if type(api) ~= "table" or type(api.GetRaceInfo) ~= "function" then
    return map
  end
  for id = 1, MAX_RACE_ID do
    local ok, info = pcall(api.GetRaceInfo, id)
    if ok and type(info) == "table" and type(info.raceName) == "string" and type(info.clientFileString) == "string" then
      map[info.raceName] = info.clientFileString
    end
  end
  return map
end

function RaceTags.FromName(raceName)
  if type(raceName) ~= "string" then
    return nil
  end
  if tagByName == nil then
    tagByName = build()
  end
  return tagByName[raceName]
end

function RaceTags._reset()
  tagByName = nil
end

ns.IdentityRaceTags = RaceTags

return RaceTags
