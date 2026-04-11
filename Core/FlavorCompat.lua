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

-- Human-readable flavor name for display and diagnostics
local FLAVOR_NAMES = {
  [MAINLINE] = "Retail",
  [CLASSIC] = "Classic Era",
  [TBC] = "TBC Classic",
  [WRATH] = "Wrath Classic",
  [CATA] = "Cata Classic",
  [MISTS] = "MoP Classic",
}

FlavorCompat.flavorName = FLAVOR_NAMES[projectId] or "Unknown"

-- Feature flags — true only on flavors that support the feature
FlavorCompat.hasWhisperTargetStatus = FlavorCompat.isRetail
FlavorCompat.hasMythicPlus = FlavorCompat.isRetail
FlavorCompat.hasCrossFactonWhispers = FlavorCompat.isRetail
FlavorCompat.hasClipboardAPI = FlavorCompat.isRetail

ns.FlavorCompat = FlavorCompat

return FlavorCompat
