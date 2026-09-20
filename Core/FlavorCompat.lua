local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = {}

local projectId = _G["WOW_PROJECT_ID"]
local MAINLINE = _G["WOW_PROJECT_MAINLINE"] or 1
local CLASSIC = _G["WOW_PROJECT_CLASSIC"] or 2
local TBC = _G["WOW_PROJECT_BURNING_CRUSADE_CLASSIC"] or 5
local WRATH = _G["WOW_PROJECT_WRATH_CLASSIC"] or 11
local CATA = _G["WOW_PROJECT_CATACLYSM_CLASSIC"] or 14
local MISTS = _G["WOW_PROJECT_MISTS_CLASSIC"] or 19

FlavorCompat.isRetail = (projectId == MAINLINE)
FlavorCompat.isClassicEra = (projectId == CLASSIC)
FlavorCompat.isTBC = (projectId == TBC)
FlavorCompat.isWrath = (projectId == WRATH)
FlavorCompat.isCata = (projectId == CATA)
FlavorCompat.isMists = (projectId == MISTS)
FlavorCompat.isClassic = not FlavorCompat.isRetail

-- ponytail: no WOW_PROJECT_FOREVER exists; GetBuildInfo toc 16xxx is the only signal
local FOREVER_TOC_MIN = 16000
local FOREVER_TOC_MAX = 17000
local tocVersion = nil
if type(_G["GetBuildInfo"]) == "function" then
  tocVersion = select(4, _G["GetBuildInfo"]())
end
FlavorCompat.isForever = type(tocVersion) == "number" and tocVersion >= FOREVER_TOC_MIN and tocVersion < FOREVER_TOC_MAX

local FLAVOR_NAMES = {
  [MAINLINE] = "Retail",
  [CLASSIC] = "Classic Era",
  [TBC] = "TBC Classic",
  [WRATH] = "Wrath Classic",
  [CATA] = "Cata Classic",
  [MISTS] = "MoP Classic",
}

FlavorCompat.flavorName = FLAVOR_NAMES[projectId] or "Unknown"
if FlavorCompat.isForever then
  FlavorCompat.flavorName = "Forever"
end

-- Feature flags — true only on flavors that support the feature
FlavorCompat.hasWhisperTargetStatus = FlavorCompat.isRetail
FlavorCompat.hasMythicPlus = FlavorCompat.isRetail and not FlavorCompat.isForever
FlavorCompat.hasCrossFactonWhispers = FlavorCompat.isRetail and not FlavorCompat.isForever
FlavorCompat.hasClipboardAPI = FlavorCompat.isRetail

ns.FlavorCompat = FlavorCompat

return FlavorCompat
