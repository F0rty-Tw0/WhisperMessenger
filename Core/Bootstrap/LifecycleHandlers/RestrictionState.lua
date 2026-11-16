local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local RestrictedActions = ns.BootstrapRestrictedActions or require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

local ChatReplyState = ns.ChatReplyState or require("WhisperMessenger.Util.ChatReplyState")
local LockdownReplay = ns.BootstrapLockdownReplay or require("WhisperMessenger.Core.Bootstrap.LockdownReplay")

local RestrictionState = {}

-- restrictions: the Bootstrap table's restriction instance. The suspend and
-- resume edges read the mythic flag, not isMythic(): the cache already holds
-- this event's state, so isMythic() would never show an edge.
local function applyRestriction(Bootstrap, restrictions, restrictionType, isActive, deps)
  if restrictionType == RestrictedActions.TYPES.ChallengeMode then
    if isActive and not restrictions.flag("mythic") then
      restrictions.setFlag("mythic", true)
      if Bootstrap.runtime and Bootstrap.runtime.suspend then
        Bootstrap.runtime.suspend()
      end
    elseif not isActive and restrictions.flag("mythic") then
      restrictions.setFlag("mythic", false)
      restrictions.setFlag("encounter", false)
      restrictions.setFlag("competitive", false)
      if Bootstrap.runtime and Bootstrap.runtime.resume then
        Bootstrap.runtime.resume()
      end
    end
    if not isActive then
      -- CHALLENGE_MODE_COMPLETED usually fires resume() (and its scrub) while
      -- this restriction is still Active, where edit-box reads can be secret
      -- and the scrub silently skips. Inactive is the last safe point to
      -- clear a /r whisper sticky left by Blizzard chat during the key.
      ChatReplyState.ScrubStaleWhisperReplyState(Bootstrap.runtime, deps.getNumChatWindows, deps.getEditBox)
    end
    -- resume() syncs the filters only on the flag edge above. A key completed
    -- before this Inactive, or one only the game reported, has no flag left,
    -- and this event is what lifts the restriction the filters wait on.
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    Common.notifyCompetitiveState(Bootstrap)
    return
  end

  if restrictionType == RestrictedActions.TYPES.Encounter then
    restrictions.setFlag("encounter", isActive)
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    Common.notifyCompetitiveState(Bootstrap)
    Common.refreshRuntimeWindow(Bootstrap)
    return
  end

  if restrictionType == RestrictedActions.TYPES.PvPMatch then
    restrictions.setFlag("competitive", isActive)
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    Common.notifyCompetitiveState(Bootstrap)
    return
  end

  -- Chat lock state lives in the restriction cache; it has no flag.
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
  local restrictions = RestrictedActions.For(Bootstrap)
  restrictions.updateFromEvent(restrictionType, newState)

  local isActive = newState == RestrictedActions.STATES.Active or newState == RestrictedActions.STATES.Activating
  applyRestriction(Bootstrap, restrictions, restrictionType, isActive, deps)

  -- Any restriction lifting may be the last one holding chat; the replay
  -- checks readiness itself.
  if newState == RestrictedActions.STATES.Inactive and Bootstrap.runtime then
    LockdownReplay.Kick(Bootstrap.runtime)
  end
  return true
end

ns.BootstrapLifecycleHandlersRestrictionState = RestrictionState
return RestrictionState
