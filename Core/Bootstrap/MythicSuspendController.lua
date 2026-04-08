local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local MythicSuspendController = {}

local DEFAULT_MYTHIC_PAUSE_NOTICE =
  "Whispers are paused in Mythic content. Incoming and outgoing messages will resume after you leave."
local SUSPEND_PRINT_MESSAGE =
  "|cff888888[WhisperMessenger]|r Suspended for mythic content. Whispers will resume when you leave."
local RESUME_PRINT_MESSAGE = "|cff888888[WhisperMessenger]|r Resumed. Whispers are active again."

function MythicSuspendController.Attach(runtime, deps)
  deps = deps or {}

  local Bootstrap = deps.Bootstrap or {}
  local isWindowVisible = deps.isWindowVisible or function()
    return false
  end
  local setWindowVisible = deps.setWindowVisible or function(...)
    local _ = ...
  end
  local refreshWindow = deps.refreshWindow or function(...)
    local _ = ...
  end

  runtime.suspend = function()
    runtime.messagingNotice = deps.mythicPauseNotice or DEFAULT_MYTHIC_PAUSE_NOTICE
    Bootstrap._wasVisibleBeforeMythic = isWindowVisible()
    setWindowVisible(false)
    if Bootstrap.unregisterChatFilters then
      Bootstrap.unregisterChatFilters()
    end

    -- Signal hooksecurefunc hooks (LinkHooks) to bail with zero addon code.
    -- Event registrations stay intact: SecretTaintGuard defers tainted args
    -- at the EventBridge layer and the drain fires on lockdown clear.
    _G._wmSuspended = true
    local printFn = deps.print or _G.print
    if type(printFn) == "function" then
      printFn(SUSPEND_PRINT_MESSAGE)
    end
  end

  runtime.resume = function()
    runtime.messagingNotice = nil
    _G._wmSuspended = nil
    local printFn = deps.print or _G.print
    if type(printFn) == "function" then
      printFn(RESUME_PRINT_MESSAGE)
    end

    if Bootstrap.syncChatFilters then
      Bootstrap.syncChatFilters()
    elseif Bootstrap.registerChatFilters then
      Bootstrap.registerChatFilters()
    end
    if Bootstrap._wasVisibleBeforeMythic then
      setWindowVisible(true)
    end
    refreshWindow()
    Bootstrap._wasVisibleBeforeMythic = nil
  end

  return runtime
end

ns.BootstrapMythicSuspendController = MythicSuspendController
return MythicSuspendController
