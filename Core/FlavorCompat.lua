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

ns.FlavorCompat = FlavorCompat

return FlavorCompat
