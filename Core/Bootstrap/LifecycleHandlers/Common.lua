local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local function L(key)
  return Localization.Text(key)
end
local QueuedSends = ns.BootstrapQueuedSends or require("WhisperMessenger.Core.Bootstrap.QueuedSends")
local RestrictedActions = ns.BootstrapRestrictedActions or require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local Common = {}

Common.COMPETITIVE_NOTICE = "Messages are paused in competitive content and will resume when you leave."

function Common.refreshRuntimeWindow(Bootstrap)
  if Bootstrap.runtime and Bootstrap.runtime.refreshWindow then
    Bootstrap.runtime.refreshWindow()
  end
end

function Common.scheduleAfter(delay, callback)
  if type(_G.C_Timer) == "table" and type(_G.C_Timer.After) == "function" then
    _G.C_Timer.After(delay, callback)
    return true
  end

  return false
end

-- The notice and the icon follow the same answer that holds sends back:
-- detection flags, the 12.0 event cache or API, and the chat lock.
function Common.notifyCompetitiveState(Bootstrap)
  local restrictions = RestrictedActions.For(Bootstrap)
  local isActive = restrictions.isRestricted()

  -- Set/clear the messaging notice on the runtime (visible banner in messenger).
  -- Skip if mythic suspend already owns the notice (its own suspend/resume
  -- manages it). That is the mythic flag, not isMythic(): a key only the game
  -- reports has had no suspend, so nothing else would show a notice.
  if Bootstrap.runtime and not restrictions.flag("mythic") then
    if isActive then
      Bootstrap.runtime.messagingNotice = L(Common.COMPETITIVE_NOTICE)
    else
      Bootstrap.runtime.messagingNotice = nil
    end
  end

  if type(Bootstrap.onCompetitiveStateChanged) == "function" then
    Bootstrap.onCompetitiveStateChanged(isActive)
  end

  if Bootstrap.runtime then
    QueuedSends.OnLockStateChanged(Bootstrap.runtime)
  end
end

ns.BootstrapLifecycleHandlersCommon = Common
return Common
