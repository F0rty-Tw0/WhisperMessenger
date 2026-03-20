local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Types = ns.TransportTypes or require("WhisperMessenger.Transport.Types")
local Availability = {}

function Availability.FromStatus(status)
  return {
    status = status,
    canWhisper = Types.WHISPERABLE[status] == true,
  }
end

ns.Availability = Availability

return Availability
