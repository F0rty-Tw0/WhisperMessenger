local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Guards = {}

-- Same rule as AutoOpenHooks: content restrictions always refuse; combat
-- refuses only a cold open, so a player mid-conversation is not stranded.
function Guards.IsRefused(runtime)
  if runtime.isCompetitiveContent() or runtime.isMythicLockdown() then
    return true
  end
  local inCombat = type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() == true
  return inCombat and not runtime.isWindowVisible()
end

-- Public functions return a boolean and never throw: an internal error is false.
function Guards.Wrap(fn)
  return function(...)
    local ok, result = pcall(fn, ...)
    return ok and result == true
  end
end

function Guards.IsNonEmptyString(value)
  return type(value) == "string" and string.find(value, "%S") ~= nil
end

ns.PublicApiGuards = Guards
return Guards
