local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local Trace = require("WhisperMessenger.Core.Trace")

return function()
  -- test_register_live_events_skips_unknown_client_events

  do
    local registered = {}
    local frame = {}

    function frame:RegisterEvent(eventName)
      if eventName == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
        error('Attempt to register unknown event "' .. eventName .. '"')
      end
      registered[eventName] = true
    end

    local ok, err = pcall(EventBridge.RegisterLiveEvents, frame)
    assert(ok, "RegisterLiveEvents should skip unsupported events instead of crashing: " .. tostring(err))
    assert(registered.CHAT_MSG_WHISPER == true, "supported whisper events should still register")
    assert(
      registered.CAN_LOCAL_WHISPER_TARGET_RESPONSE == nil,
      "unsupported whisper availability event should be skipped"
    )
  end

  -- test_register_and_unregister_lifecycle_events_skip_unknown_events

  do
    local registered = {}
    local unregistered = {}
    local frame = {}

    function frame:RegisterEvent(eventName)
      if eventName == "CLUB_MEMBER_UPDATED" then
        error('Attempt to register unknown event "' .. eventName .. '"')
      end
      registered[eventName] = true
    end

    function frame:UnregisterEvent(eventName)
      if eventName == "CLUB_MEMBER_UPDATED" then
        error('Attempt to unregister unknown event "' .. eventName .. '"')
      end
      unregistered[eventName] = true
    end

    local registerOk, registerErr = pcall(EventBridge.RegisterSuspendableLifecycleEvents, frame)
    assert(
      registerOk,
      "RegisterSuspendableLifecycleEvents should skip unsupported lifecycle events: " .. tostring(registerErr)
    )
    assert(registered.GUILD_ROSTER_UPDATE == true, "supported lifecycle events should still register")
    assert(registered.CLUB_MEMBER_UPDATED == nil, "unsupported lifecycle events should be skipped")

    local unregisterOk, unregisterErr = pcall(EventBridge.UnregisterSuspendableLifecycleEvents, frame)
    assert(
      unregisterOk,
      "UnregisterSuspendableLifecycleEvents should skip unsupported lifecycle events: " .. tostring(unregisterErr)
    )
    assert(unregistered.GUILD_ROSTER_UPDATE == true, "supported lifecycle events should still unregister")
    assert(unregistered.CLUB_MEMBER_UPDATED == nil, "unsupported lifecycle unregistration should be skipped")
  end

  -- test_trace_is_wired_through_core_trace_when_unknown_event_skipped
  -- Regression: EventBridge previously read ns.Trace (capitalized), so every
  -- Trace(...) call inside the module was a silent no-op.

  do
    local printed = {}
    local savedPrint = _G.print
    rawset(_G, "print", function(...)
      table.insert(printed, { ... })
    end)
    Trace.enable()

    local frame = {}
    function frame:RegisterEvent(eventName)
      if eventName == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
        error('Attempt to register unknown event "' .. eventName .. '"')
      end
    end

    EventBridge.RegisterLiveEvents(frame)

    Trace.disable()
    rawset(_G, "print", savedPrint)

    local found = false
    for _, call in ipairs(printed) do
      if
        call[1] == "[WM]"
        and type(call[2]) == "string"
        and string.find(call[2], "CAN_LOCAL_WHISPER_TARGET_RESPONSE", 1, true)
      then
        found = true
        break
      end
    end
    assert(found, "EventBridge should route trace output through Core.Trace when skipping unsupported events")
  end
end
