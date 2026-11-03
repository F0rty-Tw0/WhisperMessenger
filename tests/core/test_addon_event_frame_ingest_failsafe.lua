local FakeUI = require("tests.helpers.fake_ui")
local AddonEventFrame = require("WhisperMessenger.Core.Bootstrap.AddonEventFrame")

-- A whisper ingest error must not escape the event frame: the failsafe
-- catches it and hands it to the error handler instead.
return function()
  local factory = FakeUI.NewFactory()
  local Bootstrap = {}
  local EventBridge = {
    RegisterLiveEvents = function() end,
    RegisterChannelEvents = function() end,
    RegisterGroupEvents = function() end,
    RouteChannelEvent = function()
      return nil
    end,
    RouteGroupEvent = function()
      return false
    end,
    RouteLiveEvent = function()
      error("ingest broke")
    end,
  }
  local modules = {
    ["WhisperMessenger.Core.Bootstrap.EventBridge"] = EventBridge,
    ["WhisperMessenger.Core.Bootstrap.LifecycleHandlers"] = {
      Handle = function()
        return false
      end,
    },
    ["WhisperMessenger.Core.Constants"] = { LIFECYCLE_EVENT_NAMES = {} },
  }

  local frame = AddonEventFrame.Install({
    addonName = "WhisperMessenger",
    Bootstrap = Bootstrap,
    createFrame = function(frameType, name, parent)
      local created = factory.CreateFrame(frameType, name, parent)
      created.RegisterEvent = function() end
      created.UnregisterEvent = function() end
      return created
    end,
    initializeRuntime = function()
      Bootstrap.runtime = { refreshWindow = function() end }
      return Bootstrap.runtime
    end,
    loadModule = function(name)
      return modules[name] or error("unexpected module request: " .. tostring(name))
    end,
  })
  frame.scripts.OnEvent(frame, "ADDON_LOADED", "WhisperMessenger")

  local savedHandler = rawget(_G, "geterrorhandler")
  local reported = {}
  rawset(_G, "geterrorhandler", function()
    return function(err)
      reported[#reported + 1] = err
    end
  end)
  local ok, err = pcall(frame.scripts.OnEvent, frame, "CHAT_MSG_WHISPER", "hi", "Bob-Realm")
  rawset(_G, "geterrorhandler", savedHandler)

  -- test_whisper_ingest_error_does_not_escape_the_event_frame
  assert(ok, "expected the whisper ingest error caught, got " .. tostring(err))
  -- test_whisper_ingest_error_reaches_the_error_handler
  assert(#reported == 1, "expected the error handed to the error handler")
end
