local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The one reading of a panel's badge() callback, shared by the panel's tab
-- and the icon number (sum and the click's first-badged pick), so they never
-- disagree.
local PanelBadge = {}

-- Caps one panel's count so text built with %d can never overflow.
PanelBadge.MAX_COUNT = 999

--- Runs a panel's badge callback under pcall and returns a whole count.
-- Anything but a finite number, an error or a count below 1 is 0;
-- fractions round down.
-- @param badge function|nil
-- @return number
function PanelBadge.Read(badge)
  if type(badge) ~= "function" then
    return 0
  end
  local ok, value = pcall(badge)
  -- value ~= value is true only for NaN.
  if not ok or type(value) ~= "number" or value ~= value then
    return 0
  end
  local count = math.floor(value)
  if count < 1 then
    return 0
  end

  return math.min(count, PanelBadge.MAX_COUNT)
end

ns.PanelBadge = PanelBadge
return PanelBadge
