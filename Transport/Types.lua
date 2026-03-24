local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Types = {}

-- Canonical map of Enum.ChatWhisperTargetStatus codes to status strings.
-- Only 3 codes exist in the WoW API (added patch 10.0.7):
--   0 = CanWhisper (same faction, OR cross-faction guild/community member)
--   1 = Offline
--   2 = WrongFaction (opposite faction, no shared guild/community)
Types.AVAILABILITY_STATUS_BY_CODE = {
  [0] = "CanWhisper",
  [1] = "Offline",
  [2] = "WrongFaction",
  [3] = "WrongFaction",
}

-- Canonical set of statuses that allow whispering (used by Availability).
-- XFaction is a computed status (CanWhisper + opposite faction), not from the API.
-- Unavailable is a computed status: WrongFaction code 2 for same-faction cross-realm players
-- who are not BNet friends, not in guild/community, and not in party/raid.
Types.WHISPERABLE = {
  CanWhisper = true,
  XFaction = true,
  Away = true,
  Busy = true,
  BNetOnline = true,
}

-- All known channel types
Types.CHANNELS = {
  WOW = "WOW",
  BN = "BN",
}

ns.TransportTypes = Types
return Types
