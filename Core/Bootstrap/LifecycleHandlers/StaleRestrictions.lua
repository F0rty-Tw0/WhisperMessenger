local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local RestrictedActions = ns.BootstrapRestrictedActions or require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
-- stylua: ignore
local RestrictionState = ns.BootstrapLifecycleHandlersRestrictionState or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.RestrictionState")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

local pairs = pairs
local pcall = pcall
local type = type

-- A restriction's Inactive event can be missed across a loading screen
-- (leaving Mythic+, a raid or a chat-locked fight), leaving its cached state
-- stuck on and sends held back in the open world. Entering the world drops
-- any cached lock the game itself no longer reports.
local StaleRestrictions = {}

-- A cached Activating with no event since is given this long to turn Active
-- before it is treated as a missed Inactive.
StaleRestrictions.ACTIVATING_GRACE_SECONDS = 30

-- Whether the game reports restrictionType as on: true, false, or nil when it
-- can't be asked. Chat is read through InChatMessagingLockdown.
local function reportedActive(restrictionType)
  if restrictionType == RestrictedActions.TYPES.Chat then
    return RestrictedActions.ChatApiLocked()
  end
  local api = _G.C_RestrictedActions
  if type(api) ~= "table" or type(api.IsAddOnRestrictionActive) ~= "function" then
    return nil
  end
  local ok, active = pcall(api.IsAddOnRestrictionActive, restrictionType)
  if not ok or SecretValue.Is(active) or type(active) ~= "boolean" then
    return nil
  end
  return active
end

-- The API still reads off during Activating, so it can't be cleared on the
-- spot. Once the grace passes with no new event for the type and the API
-- still off, the missed Inactive is replayed.
local function expireStaleActivating(Bootstrap, restrictedActions, restrictionType)
  local updatesAtEntry = restrictedActions.updateCount(restrictionType)
  Common.scheduleAfter(StaleRestrictions.ACTIVATING_GRACE_SECONDS, function()
    if restrictedActions.updateCount(restrictionType) ~= updatesAtEntry or reportedActive(restrictionType) ~= false then
      return
    end
    RestrictionState.handleAddonRestrictionStateChanged(Bootstrap, restrictionType, RestrictedActions.STATES.Inactive)
  end)
end

-- Runs before entering the world resyncs filters, notice and suspend state,
-- so a stale Active is dropped straight from the cache.
function StaleRestrictions.Clear(Bootstrap)
  local restrictedActions = Bootstrap.runtime and Bootstrap.runtime.restrictedActions
  if restrictedActions == nil then
    return
  end
  for _, restrictionType in pairs(RestrictedActions.TYPES) do
    local cachedState = restrictedActions.cachedState(restrictionType)
    local isOn = cachedState == RestrictedActions.STATES.Active or cachedState == RestrictedActions.STATES.Activating
    if isOn and reportedActive(restrictionType) == false then
      if cachedState == RestrictedActions.STATES.Active then
        restrictedActions.updateFromEvent(restrictionType, RestrictedActions.STATES.Inactive)
      else
        expireStaleActivating(Bootstrap, restrictedActions, restrictionType)
      end
    end
  end
end

ns.BootstrapLifecycleHandlersStaleRestrictions = StaleRestrictions
return StaleRestrictions
