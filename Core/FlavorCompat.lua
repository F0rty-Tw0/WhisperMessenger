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

-- Asks the server for fresh guild member data; GUILD_ROSTER_UPDATE answers.
-- Retail has C_GuildInfo.GuildRoster, the Classic flavors the global.
-- Returns true when a request went out.
function FlavorCompat.RequestGuildRoster()
  local isInGuild = _G["IsInGuild"]
  if type(isInGuild) ~= "function" or not isInGuild() then
    return false
  end
  local guildInfo = _G["C_GuildInfo"]
  local request = type(guildInfo) == "table" and guildInfo.GuildRoster or _G["GuildRoster"]
  if type(request) ~= "function" then
    return false
  end
  request()
  return true
end

-- Localized TOC title of an installed addon; nil when unknown, blank or the API is missing.
-- The old global echoes the name for unknown addons, so reason "MISSING" outranks the title.
function FlavorCompat.GetAddOnTitle(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end
  local addOns = _G["C_AddOns"]
  local namespaced = type(addOns) == "table" and addOns.GetAddOnInfo or nil
  local getInfo = type(namespaced) == "function" and namespaced or _G["GetAddOnInfo"]
  if type(getInfo) ~= "function" then
    return nil
  end
  local ok, _, title, _, _, reason = pcall(getInfo, name)
  if not ok or reason == "MISSING" then
    return nil
  end
  if type(title) ~= "string" or not title:find("%S") then
    return nil
  end

  return title
end

ns.FlavorCompat = FlavorCompat

return FlavorCompat
