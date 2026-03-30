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
  local setWindowVisible = deps.setWindowVisible or function()
  end
  local refreshWindow = deps.refreshWindow or function()
  end

  runtime.suspend = function()
    runtime.messagingNotice = deps.mythicPauseNotice or DEFAULT_MYTHIC_PAUSE_NOTICE
    Bootstrap._wasVisibleBeforeMythic = isWindowVisible()
    setWindowVisible(false)
    if Bootstrap.unregisterChatFilters then
      Bootstrap.unregisterChatFilters()
    end

    -- Unregister live AND non-essential lifecycle events so our OnEvent
    -- handler doesn't run at all during mythic content — any addon code
    -- in the event dispatch taints Blizzard's chat frame context.
    local EventBridge = deps.getEventBridge and deps.getEventBridge() or ns.BootstrapEventBridge
    if EventBridge and Bootstrap._loadFrame then
      EventBridge.UnregisterLiveEvents(Bootstrap._loadFrame)
      EventBridge.UnregisterSuspendableLifecycleEvents(Bootstrap._loadFrame)
    end

    -- Signal hooksecurefunc hooks (LinkHooks) to bail with zero addon code.
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

    local EventBridge = deps.getEventBridge and deps.getEventBridge() or ns.BootstrapEventBridge
    if EventBridge and Bootstrap._loadFrame then
      EventBridge.RegisterLiveEvents(Bootstrap._loadFrame)
      EventBridge.RegisterSuspendableLifecycleEvents(Bootstrap._loadFrame)
    end

    if Bootstrap.registerChatFilters then
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
