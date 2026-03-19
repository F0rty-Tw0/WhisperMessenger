local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Availability = {}
local WHISPERABLE = {
  CanWhisper = true,
  CanWhisperGuild = true,
}

function Availability.FromStatus(status)
  return {
    status = status,
    canWhisper = WHISPERABLE[status] == true,
  }
end

ns.Availability = Availability

return Availability
