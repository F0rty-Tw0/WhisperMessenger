local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon
  or (type(require) == "function" and require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common"))
  or nil
local ChatReplyState = ns.ChatReplyState or (type(require) == "function" and require("WhisperMessenger.Util.ChatReplyState")) or nil

local Competitive = {}

function Competitive.handleChallengeModeEvent(Bootstrap, event, deps)
  if event == "CHALLENGE_MODE_START" then
    Bootstrap._inMythicContent = true
    if Bootstrap.runtime and Bootstrap.runtime.suspend then
      Bootstrap.runtime.suspend()
    end
    deps.trace("mythic lockdown: M+ started")
    Common.notifyCompetitiveState(Bootstrap)
    return true
  end

  if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    Bootstrap._inMythicContent = false
    Bootstrap._inEncounter = false
    Bootstrap._inCompetitiveContent = false
    if Bootstrap.runtime and Bootstrap.runtime.resume then
      Bootstrap.runtime.resume()
    end
    deps.trace(event == "CHALLENGE_MODE_COMPLETED" and "mythic lockdown: M+ completed" or "mythic lockdown: M+ reset")
    Common.notifyCompetitiveState(Bootstrap)
    return true
  end

  return false
end

function Competitive.handleEncounterEvent(Bootstrap, event, deps)
  if event == "ENCOUNTER_START" then
    Bootstrap._inEncounter = true
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    deps.trace("encounter started")
    Common.notifyCompetitiveState(Bootstrap)
    Common.refreshRuntimeWindow(Bootstrap)
    return true
  end

  if event == "ENCOUNTER_END" then
    Bootstrap._inEncounter = false
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    if ChatReplyState and ChatReplyState.ClearStaleWhisperReplyState then
      ChatReplyState.ClearStaleWhisperReplyState(deps.getNumChatWindows, deps.getEditBox)
    end
    deps.trace("encounter ended")
    Common.notifyCompetitiveState(Bootstrap)
    Common.refreshRuntimeWindow(Bootstrap)
    return true
  end

  return false
end

function Competitive.handleZoneChangedNewArea(Bootstrap, deps)
  local ContentDetector = deps.getContentDetector()

  -- Update competitive content flag on every zone change so the chat
  -- filter bypasses correctly when entering/leaving PvP or arenas.
  if Bootstrap._inCompetitiveContent or Bootstrap._inMythicContent then
    local isCompetitive = ContentDetector and ContentDetector.IsCompetitiveContent(_G.GetInstanceInfo) or false
    Bootstrap._inCompetitiveContent = isCompetitive
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    Common.notifyCompetitiveState(Bootstrap)
  end

  if not Bootstrap._inMythicContent then
    return true
  end

  local isMythic = ContentDetector and ContentDetector.IsMythicRestricted(_G.GetInstanceInfo) or false
  deps.trace("ZONE_CHANGED_NEW_AREA wasMythic=true isMythic=" .. tostring(isMythic))
  if not isMythic then
    Bootstrap._inMythicContent = false
    if Bootstrap.runtime and Bootstrap.runtime.resume then
      Bootstrap.runtime.resume()
    end

    local PresenceCache = deps.getPresenceCache()
    if PresenceCache then
      Common.scheduleAfter(2, function()
        if Bootstrap._inMythicContent then
          return
        end
        deps.trace("PresenceCache: rebuild after mythic exit")
        PresenceCache.Rebuild()
        Common.refreshRuntimeWindow(Bootstrap)
      end)
    end

    deps.trace("mythic lockdown: resumed via zone change")
    Common.notifyCompetitiveState(Bootstrap)
  end

  return true
end

ns.BootstrapLifecycleHandlersCompetitive = Competitive
return Competitive
