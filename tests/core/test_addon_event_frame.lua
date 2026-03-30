local FakeUI = require("tests.helpers.fake_ui")
local AddonEventFrame = require("WhisperMessenger.Core.Bootstrap.AddonEventFrame")

return function()
  local factory = FakeUI.NewFactory()
  local createdFrames = {}
  local calls = {}
  local loadedModules = {}
  local lifecycleHandled = {
    PLAYER_ENTERING_WORLD = true,
  }
  local liveEvents = {
    CHAT_MSG_WHISPER = true,
    CHAT_MSG_WHISPER_INFORM = true,
    CHAT_MSG_AFK = true,
    CHAT_MSG_DND = true,
  }
  local lifecycleEvents = {
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGOUT",
  }

  local function createFrame(frameType, name, parent)
    local frame = factory.CreateFrame(frameType, name, parent)
    createdFrames[#createdFrames + 1] = frame

    function frame:RegisterEvent(eventName)
      self.events = self.events or {}
      self.events[eventName] = true
    end

    function frame:UnregisterEvent(eventName)
      if self.events then
        self.events[eventName] = nil
      end
    end

    return frame
  end

  local Bootstrap = {}
  local EventBridge = {
    RegisterLiveEvents = function(frame)
      calls[#calls + 1] = "RegisterLiveEvents"
      for eventName in pairs(liveEvents) do
        frame:RegisterEvent(eventName)
      end
    end,
    RouteLiveEvent = function(runtime, refreshWindow, eventName, ...)
      calls[#calls + 1] = "RouteLiveEvent:" .. eventName .. ":" .. tostring((...))
      if Bootstrap.runtime ~= nil then
        assert(runtime == Bootstrap.runtime, "expected RouteLiveEvent runtime to match bootstrap runtime")
        assert(refreshWindow == Bootstrap.runtime.refreshWindow, "expected RouteLiveEvent refreshWindow callback")
      else
        assert(runtime == nil, "expected nil runtime when bootstrap runtime is unset")
        assert(refreshWindow == nil, "expected nil refresh callback when bootstrap runtime is unset")
      end
    end,
  }
  local LifecycleHandlers = {
    Handle = function(receivedBootstrap, eventName, deps)
      calls[#calls + 1] = "LifecycleHandlers:" .. eventName
      assert(receivedBootstrap == Bootstrap, "expected lifecycle bootstrap reference")
      assert(type(deps.loadModule) == "function", "expected lifecycle loadModule dependency")
      assert(type(deps.trace) == "function", "expected lifecycle trace dependency")
      assert(type(deps.getContentDetector) == "function", "expected lifecycle content detector accessor")
      assert(type(deps.getPresenceCache) == "function", "expected lifecycle presence cache accessor")
      return lifecycleHandled[eventName] == true
    end,
  }
  local Constants = {
    LIFECYCLE_EVENT_NAMES = lifecycleEvents,
  }

  local function loadModule(name, _key)
    loadedModules[#loadedModules + 1] = name
    if name == "WhisperMessenger.Core.Bootstrap.EventBridge" then
      return EventBridge
    end
    if name == "WhisperMessenger.Core.Bootstrap.LifecycleHandlers" then
      return LifecycleHandlers
    end
    if name == "WhisperMessenger.Core.Constants" then
      return Constants
    end

    error("unexpected module request: " .. tostring(name))
  end

  local function initializeRuntime()
    calls[#calls + 1] = "initializeRuntime"
    Bootstrap.runtime = {
      refreshWindow = function()
      end,
      autoOpenCoordinator = {
        installDeferredPoller = function()
          calls[#calls + 1] = "installDeferredPoller"
        end,
      },
    }
    return Bootstrap.runtime
  end

  local frame = AddonEventFrame.Install({
    addonName = "WhisperMessenger",
    Bootstrap = Bootstrap,
    createFrame = createFrame,
    initializeRuntime = initializeRuntime,
    loadModule = loadModule,
    trace = function()
    end,
  })

  assert(frame ~= nil, "expected load frame from install")
  assert(frame == Bootstrap._loadFrame, "expected install to preserve Bootstrap._loadFrame")
  assert(#createdFrames == 1, "expected install to create exactly one frame")
  assert(frame.name == "WhisperMessengerLoadFrame", "expected whisper messenger load frame name")
  assert(frame.events.ADDON_LOADED == true, "expected ADDON_LOADED registration on install")
  assert(type(frame.scripts.OnEvent) == "function", "expected OnEvent script installation")
  assert(#loadedModules == 0, "expected lazy module loading before first event")

  frame.scripts.OnEvent(frame, "ADDON_LOADED", "OtherAddon")
  assert(#calls == 0, "expected other addon loads to no-op")
  assert(#loadedModules == 0, "expected wrong addon name to avoid module loads")
  assert(frame.events.ADDON_LOADED == true, "expected ADDON_LOADED to stay registered after wrong addon")

  frame.scripts.OnEvent(frame, "ADDON_LOADED", "WhisperMessenger")
  assert(
    table.concat(calls, ",") == "initializeRuntime,RegisterLiveEvents,installDeferredPoller",
    "expected ADDON_LOADED to initialize, register live events, and install deferred poller"
  )
  assert(
    table.concat(loadedModules, ",") == "WhisperMessenger.Core.Bootstrap.EventBridge,WhisperMessenger.Core.Constants",
    "expected ADDON_LOADED to lazy-load EventBridge and Constants"
  )
  assert(frame.events.ADDON_LOADED == nil, "expected ADDON_LOADED to unregister after initialization")
  for eventName in pairs(liveEvents) do
    assert(frame.events[eventName] == true, "expected live event registration for " .. eventName)
  end
  for _, eventName in ipairs(lifecycleEvents) do
    assert(frame.events[eventName] == true, "expected lifecycle event registration for " .. eventName)
  end

  calls = {}
  loadedModules = {}
  frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD")
  assert(
    table.concat(calls, ",") == "LifecycleHandlers:PLAYER_ENTERING_WORLD",
    "expected handled lifecycle event to stop before live routing"
  )
  assert(
    table.concat(loadedModules, ",") == "WhisperMessenger.Core.Bootstrap.LifecycleHandlers",
    "expected lifecycle handlers to lazy-load on first non-addon event"
  )

  calls = {}
  loadedModules = {}
  frame.scripts.OnEvent(frame, "CHAT_MSG_WHISPER", "hello there")
  assert(
    table.concat(calls, ",") == "LifecycleHandlers:CHAT_MSG_WHISPER,RouteLiveEvent:CHAT_MSG_WHISPER:hello there",
    "expected later events to route through lifecycle handlers before EventBridge"
  )
  assert(#loadedModules == 0, "expected cached handlers and bridge on later live event routing")

  calls = {}
  Bootstrap._inMythicContent = true
  frame.scripts.OnEvent(frame, "CHAT_MSG_WHISPER", "blocked")
  assert(
    table.concat(calls, ",") == "LifecycleHandlers:CHAT_MSG_WHISPER",
    "expected mythic guard to stop live routing after lifecycle handling"
  )

  local noFrameResult = AddonEventFrame.Install({
    createFrame = nil,
  })
  assert(noFrameResult == nil, "expected Install to return nil when createFrame is unavailable")

  calls = {}
  Bootstrap._inMythicContent = false
  Bootstrap.runtime = nil
  frame.scripts.OnEvent(frame, "CHAT_MSG_DND", "without runtime")
  assert(
    table.concat(calls, ",") == "LifecycleHandlers:CHAT_MSG_DND,RouteLiveEvent:CHAT_MSG_DND:without runtime",
    "expected live routing to tolerate missing runtime"
  )
end
