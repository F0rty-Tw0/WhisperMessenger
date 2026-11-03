local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = {}

local projectId = _G["WOW_PROJECT_ID"]
local MAINLINE = _G["WOW_PROJECT_MAINLINE"] or 1

FlavorCompat.projectId = projectId
FlavorCompat.isRetail = (projectId == MAINLINE)
FlavorCompat.isClassic = not FlavorCompat.isRetail

-- ponytail: no WOW_PROJECT_FOREVER exists; GetBuildInfo toc 16xxx is the only signal
local FOREVER_TOC_MIN = 16000
local FOREVER_TOC_MAX = 17000
local tocVersion = nil
if type(_G["GetBuildInfo"]) == "function" then
  tocVersion = select(4, _G["GetBuildInfo"]())
end
FlavorCompat.isForever = type(tocVersion) == "number" and tocVersion >= FOREVER_TOC_MIN and tocVersion < FOREVER_TOC_MAX

-- Region id of the current game client; nil without the API.
function FlavorCompat.CurrentRegion()
  local getCurrentRegion = _G["GetCurrentRegion"]
  if type(getCurrentRegion) ~= "function" then
    return nil
  end
  local ok, regionId = pcall(getCurrentRegion)
  return ok and regionId or nil
end

-- Enum.SeasonID of a Classic Era realm; nil without a season or the API.
function FlavorCompat.ActiveSeason()
  local seasons = _G["C_Seasons"]
  if type(seasons) ~= "table" or type(seasons.GetActiveSeason) ~= "function" then
    return nil
  end
  local ok, seasonId = pcall(seasons.GetActiveSeason)
  return ok and seasonId or nil
end

-- Feature flags — true only on flavors that support the feature
FlavorCompat.hasMythicPlus = FlavorCompat.isRetail and not FlavorCompat.isForever

ns.FlavorCompat = FlavorCompat

return FlavorCompat
