local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")

local LockdownState = {}

local function resolveNow(deps)
  if deps and type(deps.now) == "function" then
    return deps.now()
  end
  if type(_G.time) == "function" then
    return _G.time()
  end
  return 0
end

function LockdownState.Initialize(Bootstrap)
  Bootstrap.lockdown = {
    active = false,
    since = 0,
    source = "init",
  }
end

function LockdownState.IsActive(Bootstrap)
  return Bootstrap.lockdown ~= nil and Bootstrap.lockdown.active == true
end

-- Sync(Bootstrap, eventName, deps) -> (changed, wasActive, isActive)
-- Reads FlavorCompat.InChatMessagingLockdown() and updates Bootstrap.lockdown
-- when the value differs from the cached state. Does NOT fire side effects —
-- the caller decides what to do based on the transition.
function LockdownState.Sync(Bootstrap, eventName, deps)
  if Bootstrap.lockdown == nil then
    LockdownState.Initialize(Bootstrap)
  end

  local wasActive = Bootstrap.lockdown.active == true
  local isActive = FlavorCompat.InChatMessagingLockdown() == true

  if wasActive == isActive then
    return false, wasActive, isActive
  end

  Bootstrap.lockdown.active = isActive
  Bootstrap.lockdown.since = resolveNow(deps)
  Bootstrap.lockdown.source = eventName or "unknown"

  return true, wasActive, isActive
end

ns.BootstrapLockdownState = LockdownState
return LockdownState
