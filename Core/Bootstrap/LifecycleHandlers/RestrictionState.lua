local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local RestrictedActions = ns.BootstrapRestrictedActions or require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

local ChatReplyState = ns.ChatReplyState or (type(require) == "function" and require("WhisperMessenger.Util.ChatReplyState")) or nil
local LockdownReplay = ns.BootstrapLockdownReplay or require("WhisperMessenger.Core.Bootstrap.LockdownReplay")

local RestrictionState = {}

local function applyRestriction(Bootstrap, restrictionType, isActive, deps)
  if restrictionType == RestrictedActions.TYPES.ChallengeMode then
    if isActive and not Bootstrap._inMythicContent then
      Bootstrap._inMythicContent = true
      if Bootstrap.runtime and Bootstrap.runtime.suspend then
        Bootstrap.runtime.suspend()
      end
    elseif not isActive and Bootstrap._inMythicContent then
      Bootstrap._inMythicContent = false
      Bootstrap._inEncounter = false
      Bootstrap._inCompetitiveContent = false
      if Bootstrap.runtime and Bootstrap.runtime.resume then
        Bootstrap.runtime.resume()
      end
    end
    if not isActive and ChatReplyState and ChatReplyState.ScrubStaleWhisperReplyState then
      -- CHALLENGE_MODE_COMPLETED usually fires resume() (and its scrub) while
      -- this restriction is still Active, where edit-box reads can be secret
      -- and the scrub silently skips. Inactive is the last safe point to
      -- clear a /r whisper sticky left by Blizzard chat during the key.
      ChatReplyState.ScrubStaleWhisperReplyState(Bootstrap.runtime, deps.getNumChatWindows, deps.getEditBox)
    end
    Common.notifyCompetitiveState(Bootstrap)
    return
  end

  if restrictionType == RestrictedActions.TYPES.Encounter then
    Bootstrap._inEncounter = isActive
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    Common.notifyCompetitiveState(Bootstrap)
    Common.refreshRuntimeWindow(Bootstrap)
    return
  end

  if restrictionType == RestrictedActions.TYPES.PvPMatch then
    Bootstrap._inCompetitiveContent = isActive
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    Common.notifyCompetitiveState(Bootstrap)
    return
  end

  -- Chat lock state lives in the restriction cache; no Bootstrap flag.
  if restrictionType == RestrictedActions.TYPES.Chat then
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    Common.notifyCompetitiveState(Bootstrap)
    Common.refreshRuntimeWindow(Bootstrap)
  end
end

function RestrictionState.handleAddonRestrictionStateChanged(Bootstrap, restrictionType, newState, deps)
  deps = deps or {}
  local ra = Bootstrap.runtime and Bootstrap.runtime.restrictedActions
  if ra and ra.updateFromEvent then
    ra.updateFromEvent(restrictionType, newState)
  end

  local isActive = newState == RestrictedActions.STATES.Active or newState == RestrictedActions.STATES.Activating
  applyRestriction(Bootstrap, restrictionType, isActive, deps)

  -- Any restriction lifting may be the last one holding chat; the replay
  -- checks readiness itself.
  if newState == RestrictedActions.STATES.Inactive and Bootstrap.runtime then
    LockdownReplay.Kick(Bootstrap.runtime)
  end
  return true
end

ns.BootstrapLifecycleHandlersRestrictionState = RestrictionState
return RestrictionState
