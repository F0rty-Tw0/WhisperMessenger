local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = ns.BootstrapLifecycleHandlersCommon or require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local ChatReplyState = ns.ChatReplyState or require("WhisperMessenger.Util.ChatReplyState")
local FlavorCompat = ns.FlavorCompat or require("WhisperMessenger.Core.FlavorCompat")
local RestrictedActions = ns.BootstrapRestrictedActions or require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

local Competitive = {}

local function canClearStaleWhisperReplyState(runtime, deps)
  if runtime then
    local _, resolved = ChatReplyState.CaptureStaleWhisperReplyTarget(runtime, deps.getNumChatWindows, deps.getEditBox)
    return resolved ~= false
  end
  return true
end

function Competitive.handleChallengeModeEvent(Bootstrap, event)
  if
    (event == "CHALLENGE_MODE_START" or event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET") and not FlavorCompat.hasMythicPlus
  then
    return true
  end

  -- The suspend and resume edges below read the mythic flag: it is what
  -- records that this addon suspended.
  local restrictions = RestrictedActions.For(Bootstrap)
  if event == "CHALLENGE_MODE_START" then
    -- Guard against double-suspend (ADDON_RESTRICTION_STATE_CHANGED may have
    -- suspended already): a second suspend() would clobber the saved
    -- window-visibility state with the already-hidden window.
    if not restrictions.flag("mythic") then
      restrictions.setFlag("mythic", true)
      if Bootstrap.runtime and Bootstrap.runtime.suspend then
        Bootstrap.runtime.suspend()
      end
    end
    Common.notifyCompetitiveState(Bootstrap)
    return true
  end

  if event == "CHALLENGE_MODE_COMPLETED" or event == "CHALLENGE_MODE_RESET" then
    if restrictions.flag("mythic") then
      restrictions.setFlag("mythic", false)
      restrictions.setFlag("encounter", false)
      restrictions.setFlag("competitive", false)
      if Bootstrap.runtime and Bootstrap.runtime.resume then
        Bootstrap.runtime.resume()
      end
    end
    Common.notifyCompetitiveState(Bootstrap)
    return true
  end

  return false
end

-- Raw encounter events also fire for unrestricted legacy bosses; ADDON_RESTRICTION_STATE_CHANGED owns Midnight restriction state.
function Competitive.handleEncounterEvent(Bootstrap, event, deps)
  if event == "ENCOUNTER_START" then
    return true
  end

  if event == "ENCOUNTER_END" then
    if canClearStaleWhisperReplyState(Bootstrap.runtime, deps) then
      ChatReplyState.ClearStaleWhisperReplyState(deps.getNumChatWindows, deps.getEditBox)
    end
    return true
  end

  return false
end

function Competitive.handleCombatStart(Bootstrap)
  local runtime = Bootstrap.runtime
  local settings = runtime and runtime.accountState and runtime.accountState.settings
  if
    settings
    and settings.hideOnCombat == true
    and runtime
    and runtime.isWindowVisible
    and runtime.setWindowVisible
    and runtime.isWindowVisible()
  then
    runtime.setWindowVisible(false)
    -- Set after hiding: any open (WindowRuntime.setWindowVisible) clears it.
    runtime.hiddenByCombat = true
  end
  return true
end

-- Reopens only what combat hid; a Mythic+ suspend owns visibility until resume.
local function reopenWindowHiddenByCombat(Bootstrap)
  local runtime = Bootstrap.runtime
  if not (runtime and runtime.hiddenByCombat) then
    return
  end
  runtime.hiddenByCombat = nil
  if RestrictedActions.For(Bootstrap).flag("mythic") or not (runtime.isWindowVisible and runtime.setWindowVisible) then
    return
  end
  -- No composer focus: the player's movement keys would land in it.
  if not runtime.isWindowVisible() then
    runtime.setWindowVisible(true, { focusComposer = false })
  end
end

function Competitive.handleCombatEnd(Bootstrap, deps)
  if canClearStaleWhisperReplyState(Bootstrap.runtime, deps) then
    ChatReplyState.ClearStaleWhisperReplyState(deps.getNumChatWindows, deps.getEditBox)
  end
  reopenWindowHiddenByCombat(Bootstrap)
  return true
end

function Competitive.handleZoneChangedNewArea(Bootstrap, deps)
  local ContentDetector = deps.getContentDetector()
  local restrictions = RestrictedActions.For(Bootstrap)

  -- Update competitive content flag on every zone change so the chat
  -- filter bypasses correctly when entering/leaving PvP or arenas.
  if restrictions.flag("competitive") or restrictions.flag("mythic") then
    local isCompetitive = ContentDetector and ContentDetector.IsCompetitiveContent(_G.GetInstanceInfo) or false
    restrictions.setFlag("competitive", isCompetitive)
    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    end
    Common.notifyCompetitiveState(Bootstrap)
  end

  if not restrictions.flag("mythic") then
    return true
  end

  local isMythic = ContentDetector and ContentDetector.IsMythicRestricted(_G.GetInstanceInfo) or false
  if not isMythic then
    restrictions.setFlag("mythic", false)
    if Bootstrap.runtime and Bootstrap.runtime.resume then
      Bootstrap.runtime.resume()
    end

    local PresenceCache = deps.getPresenceCache()
    if PresenceCache then
      Common.scheduleAfter(2, function()
        if RestrictedActions.For(Bootstrap).flag("mythic") then
          return
        end
        PresenceCache.Rebuild()
        Common.refreshRuntimeWindow(Bootstrap)
      end)
    end

    Common.notifyCompetitiveState(Bootstrap)
  end

  return true
end

ns.BootstrapLifecycleHandlersCompetitive = Competitive
return Competitive
