local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- How GamepadNav takes its deps: tests pass fakes, the game's own are the
-- defaults.
local GamepadDeps = {}

-- A dep given as false counts as absent: no fallback to the default.
---@generic T
---@param deps table
---@param field string
---@param default T
---@return T
function GamepadDeps.pick(deps, field, default)
  local value = deps[field]
  if value == nil then
    return default
  end
  if value == false then
    return nil
  end
  return value
end

function GamepadDeps.defaultInCombat()
  local restrictions = _G.C_RestrictedActions
  local types = _G.Enum and _G.Enum.AddOnRestrictionType
  if type(restrictions) == "table" and type(restrictions.IsAddOnRestrictionActive) == "function" and types and types.Combat ~= nil then
    return restrictions.IsAddOnRestrictionActive(types.Combat) == true
  end
  local inCombatLockdown = _G.InCombatLockdown
  return type(inCombatLockdown) == "function" and inCombatLockdown() == true
end

function GamepadDeps.defaultAfter(delay, fn)
  _G.C_Timer.After(delay, fn)
end

function GamepadDeps.defaultCreateFrame()
  return _G.CreateFrame("Frame")
end

ns.MessengerWindowGamepadDeps = GamepadDeps

return GamepadDeps
