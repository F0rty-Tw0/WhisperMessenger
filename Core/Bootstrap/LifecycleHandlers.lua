local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon
  or (type(require) == "function" and require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common"))
  or nil

local Competitive = ns.BootstrapLifecycleHandlersCompetitive
  or (type(require) == "function" and require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Competitive"))
  or nil

local Presence = ns.BootstrapLifecycleHandlersPresence
  or (type(require) == "function" and require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence"))
  or nil

local RestrictionState = ns.BootstrapLifecycleHandlersRestrictionState
  or (type(require) == "function" and require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.RestrictionState"))
  or nil

local LifecycleHandlers = {}

function LifecycleHandlers.Handle(Bootstrap, event, deps, ...)
  if event == "ADDON_RESTRICTION_STATE_CHANGED" then
    local restrictionType, newState = ...
    return RestrictionState.handleAddonRestrictionStateChanged(Bootstrap, restrictionType, newState, deps)
  end

  if event == "BN_FRIEND_LIST_SIZE_CHANGED" or event == "BN_FRIEND_INFO_CHANGED" then
    return Presence.handleBNetFriendEvent(Bootstrap, deps)
  end

  if event == "PLAYER_LOGOUT" then
    return Presence.handlePlayerLogout(Bootstrap, deps)
  end

  if Competitive.handleChallengeModeEvent(Bootstrap, event, deps) then
    return true
  end

  if Competitive.handleEncounterEvent(Bootstrap, event, deps) then
    return true
  end

  if event == "ZONE_CHANGED_NEW_AREA" then
    return Competitive.handleZoneChangedNewArea(Bootstrap, deps)
  end

  if event == "PLAYER_ENTERING_WORLD" then
    return Presence.handlePlayerEnteringWorld(Bootstrap, deps)
  end

  if event == "UPDATE_BINDINGS" then
    -- User opened the keybindings UI and (possibly) remapped REPLY.
    -- Re-run syncReplyKey so our override tracks the new key without /reload.
    if Bootstrap.runtime and Bootstrap.runtime.syncReplyKey then
      Bootstrap.runtime.syncReplyKey()
    end
    return true
  end

  if
    event == "GUILD_ROSTER_UPDATE"
    or event == "CLUB_MEMBER_UPDATED"
    or event == "CLUB_MEMBER_ADDED"
    or event == "CLUB_MEMBER_REMOVED"
  then
    return Presence.handlePresenceInvalidation(Bootstrap, event, deps)
  end

  return false
end

ns.BootstrapLifecycleHandlers = LifecycleHandlers
return LifecycleHandlers
