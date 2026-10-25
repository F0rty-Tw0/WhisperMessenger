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

-- True while any badge() runs. A badge() that calls back into the API
-- re-enters a read (its own or another panel's) through the icon and tab
-- refreshes; that inner read is 0, so the nesting stops after one level.
local reading = false

--- Runs a panel's badge callback under pcall and returns a whole count.
-- Anything but a finite number, an error, a secret value or a count below 1
-- is 0; fractions round down.
-- @param badge function|nil
-- @return number
function PanelBadge.Read(badge)
  if type(badge) ~= "function" then
    return 0
  end
  if reading then
    return 0
  end
  reading = true
  local ok, value = pcall(badge)
  reading = false
  if not ok or type(value) ~= "number" then
    return 0
  end
  -- A secret value errors on compare, so it is ruled out first.
  local issecretvalue = _G.issecretvalue
  if issecretvalue and issecretvalue(value) then
    return 0
  end
  -- value ~= value is true only for NaN.
  if value ~= value then
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
