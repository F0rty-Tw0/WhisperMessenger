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

-- Chat-secrecy taint API wrappers (Retail 10.0+ only).
--
-- References are probed from _G at call time so that tests can swap globals
-- between require() calls without needing module-level caching to interfere.
-- In production the globals are always present on Retail and always absent on
-- Classic, so there is no meaningful perf difference.

-- IsSecretValue(value) -> boolean
-- Returns true when `value` is a Blizzard "secret string" tainted by M+/PvP
-- chat-secrecy lockdown. Safe to call on all flavors; returns false on Classic.
function FlavorCompat.IsSecretValue(value)
  local fn = _G.issecretvalue
  if type(fn) == "function" then
    return fn(value)
  end
  return false
end

-- HasAnySecretValues(...) -> boolean
-- Returns true when any of the vararg values is a secret string.
-- Safe to call on all flavors; returns false on Classic.
function FlavorCompat.HasAnySecretValues(...)
  local fn = _G.hasanysecretvalues
  if type(fn) == "function" then
    return fn(...)
  end
  return false
end

-- InChatMessagingLockdown() -> boolean
-- Returns true while Blizzard's chat-secrecy lockdown is active (M+, Mythic
-- raid, certain PvP brackets). Safe to call on all flavors; returns false on
-- Classic or when the API is absent.
function FlavorCompat.InChatMessagingLockdown()
  local chatInfo = _G.C_ChatInfo
  if type(chatInfo) == "table" and type(chatInfo.InChatMessagingLockdown) == "function" then
    return chatInfo.InChatMessagingLockdown()
  end
  return false
end

ns.FlavorCompat = FlavorCompat

return FlavorCompat
