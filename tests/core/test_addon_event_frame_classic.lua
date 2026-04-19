-- Regression: Classic / pre-12.0 clients don't know
-- ADDON_RESTRICTION_STATE_CHANGED. Registering it raises "Attempt to register
-- unknown event". AddonEventFrame.Install must tolerate that and keep
-- registering the remaining lifecycle events.
local FakeUI = require("tests.helpers.fake_ui")
local AddonEventFrame = require("WhisperMessenger.Core.Bootstrap.AddonEventFrame")

return function()
  local factory = FakeUI.NewFactory()

  local function createFrame(frameType, name, parent)
    local frame = factory.CreateFrame(frameType, name, parent)
    function frame:RegisterEvent(eventName)
      if eventName == "ADDON_RESTRICTION_STATE_CHANGED" then
        error('Attempt to register unknown event "ADDON_RESTRICTION_STATE_CHANGED"')
      end
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
    RegisterLiveEvents = function() end,
    RegisterChannelEvents = function() end,
    RegisterGroupEvents = function() end,
    RouteChannelEvent = function() end,
    RouteGroupEvent = function()
      return false
    end,
    RouteLiveEvent = function() end,
  }
  local LifecycleHandlers = {
    Handle = function()
      return false
    end,
  }
  local Constants = {
    LIFECYCLE_EVENT_NAMES = {
      "BN_FRIEND_LIST_SIZE_CHANGED",
      "ADDON_RESTRICTION_STATE_CHANGED",
      "UPDATE_BINDINGS",
    },
  }

  local function loadModule(name, _key)
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

  local frame = AddonEventFrame.Install({
    addonName = "WhisperMessenger",
    Bootstrap = Bootstrap,
    createFrame = createFrame,
    initializeRuntime = function()
      Bootstrap.runtime = { refreshWindow = function() end }
      return Bootstrap.runtime
    end,
    loadModule = loadModule,
    trace = function() end,
  })

  assert(frame ~= nil, "expected install to return a frame")

  local ok, err = pcall(frame.scripts.OnEvent, frame, "ADDON_LOADED", "WhisperMessenger")
  assert(ok, "expected install to tolerate unknown lifecycle events; got error: " .. tostring(err))
  assert(
    frame.events["BN_FRIEND_LIST_SIZE_CHANGED"] == true,
    "expected lifecycle events before the unknown one to register"
  )
  assert(frame.events["UPDATE_BINDINGS"] == true, "expected lifecycle events after the unknown one to register")
  assert(frame.events["ADDON_RESTRICTION_STATE_CHANGED"] == nil, "expected unknown lifecycle event to be skipped")
end
