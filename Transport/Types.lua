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
--   WrongFaction (3)    = opposite faction, or a same-faction player the check cannot reach
-- Both CanWhisper codes map to "CanWhisper"; the opposite-faction branch of
-- WoWStatus.ApplyCached turns that into XFaction.
local function buildStatusByCode()
  local enum = type(_G.Enum) == "table" and _G.Enum.ChatWhisperTargetStatus
  local codes = type(enum) == "table" and enum or {}
  local statusByCode = {}
  statusByCode[codes.CanWhisper or 0] = "CanWhisper"
  statusByCode[codes.CanWhisperGuild or 1] = "CanWhisper"
  statusByCode[codes.Offline or 2] = "Offline"
  statusByCode[codes.WrongFaction or 3] = "WrongFaction"

  return statusByCode
end

Types.AVAILABILITY_STATUS_BY_CODE = buildStatusByCode()

-- Canonical set of statuses that allow whispering (used by Availability).
-- XFaction is a computed status (CanWhisper + opposite faction), not from the API.
-- Unavailable is a computed status: WrongFaction for same-faction cross-realm players
-- who are not BNet friends, not in guild/community, and not in party/raid.
Types.WHISPERABLE = {
  CanWhisper = true,
  XFaction = true,
  Away = true,
  Busy = true,
  BNetOnline = true,
}

ns.TransportTypes = Types
return Types
