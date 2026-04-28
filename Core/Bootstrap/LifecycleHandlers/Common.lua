local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Common = {}

Common.COMPETITIVE_NOTICE = "Whispers are paused in competitive content. Messages will resume when you leave."

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

function Common.notifyCompetitiveState(Bootstrap)
  local isActive = Bootstrap._inCompetitiveContent == true or Bootstrap._inMythicContent == true or Bootstrap._inEncounter == true

  -- Set/clear the messaging notice on the runtime (visible banner in messenger).
  -- Skip if mythic suspend already owns the notice (its own suspend/resume manages it).
  if Bootstrap.runtime and not Bootstrap._inMythicContent then
    if isActive then
      Bootstrap.runtime.messagingNotice = Common.COMPETITIVE_NOTICE
    else
      Bootstrap.runtime.messagingNotice = nil
    end
  end

  if type(Bootstrap.onCompetitiveStateChanged) == "function" then
    Bootstrap.onCompetitiveStateChanged(isActive)
  end
end

ns.BootstrapLifecycleHandlersCommon = Common
return Common
