local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WindowScale = {
  MIN = 0.75,
  MAX = 1.50,
  STEP = 0.05,
  DEFAULT = 1.00,
}
local ROUNDING_TOLERANCE = 1e-12

function WindowScale.Normalize(value)
  if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge or value < WindowScale.MIN or value > WindowScale.MAX then
    return WindowScale.DEFAULT
  end

  local steps = math.floor(((value - WindowScale.MIN) / WindowScale.STEP) + 0.5 + ROUNDING_TOLERANCE)
  local normalized = WindowScale.MIN + (steps * WindowScale.STEP)
  return math.floor((normalized * 100) + 0.5) / 100
end

ns.MessengerWindowWindowScale = WindowScale

return WindowScale
