local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Types = {}

-- Canonical map of Enum.ChatWhisperTargetStatus codes to status strings.
-- The game's enum has 4 members (added patch 10.0.7); the literals below are
-- the fallback when the enum is missing:
--   CanWhisper (0)      = reachable
--   CanWhisperGuild (1) = reachable cross-faction guild/community member
--   Offline (2)         = offline
--   WrongFaction (3)    = wrong faction
-- CanWhisperGuild stays its own status: it proves nothing about faction.
-- WoWStatus.ResolveGuild turns it into XFaction or CanWhisper for display.
local STATUS_NAMES = { "CanWhisper", "CanWhisperGuild", "Offline", "WrongFaction" }
local FALLBACK_CODES = { CanWhisper = 0, CanWhisperGuild = 1, Offline = 2, WrongFaction = 3 }

local function buildStatusByCode()
  local enum = type(_G.Enum) == "table" and _G.Enum.ChatWhisperTargetStatus
  local codes = type(enum) == "table" and enum or {}
  local statusByCode = {}
  for _, name in ipairs(STATUS_NAMES) do
    if codes[name] ~= nil then
      statusByCode[codes[name]] = name
    end
  end
  -- A name the enum lacks falls back to its literal, unless the enum already uses that code.
  for _, name in ipairs(STATUS_NAMES) do
    if codes[name] == nil and statusByCode[FALLBACK_CODES[name]] == nil then
      statusByCode[FALLBACK_CODES[name]] = name
    end
  end

  return statusByCode
end

Types.AVAILABILITY_STATUS_BY_CODE = buildStatusByCode()

-- Canonical set of statuses that allow whispering (used by Availability).
-- XFaction is a computed status (CanWhisper + opposite faction), not from the API.
-- Unavailable is a computed status: WrongFaction for same-faction cross-realm players
-- who are not BNet friends, not in guild/community, and not in party/raid.
Types.WHISPERABLE = {
  CanWhisper = true,
  CanWhisperGuild = true,
  XFaction = true,
  Away = true,
  Busy = true,
  BNetOnline = true,
}

ns.TransportTypes = Types
return Types
