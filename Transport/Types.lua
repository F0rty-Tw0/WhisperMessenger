local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Types = {}

-- Canonical map of status codes to status strings (used by BNetResolver)
Types.AVAILABILITY_STATUS_BY_CODE = {
  [0] = "CanWhisper",
  [1] = "Offline",
  [2] = "CanWhisperGuild",
  [3] = "WrongFaction",
}

-- Canonical set of statuses that allow whispering (used by Availability)
Types.WHISPERABLE = {
  CanWhisper = true,
  CanWhisperGuild = true,
  Away = true,
  Busy = true,
}

-- All known channel types
Types.CHANNELS = {
  WOW = "WOW",
  BN = "BN",
}

ns.TransportTypes = Types
return Types
