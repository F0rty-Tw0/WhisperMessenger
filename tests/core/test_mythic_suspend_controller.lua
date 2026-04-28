local MythicSuspendController = require("WhisperMessenger.Core.Bootstrap.MythicSuspendController")

return function()
  -- test_attach_installs_suspend_resume_and_preserves_mythic_flags

  do
    local calls = {}
    local runtime = {}
    local Bootstrap = {
      _loadFrame = {},
      unregisterChatFilters = function()
        calls[#calls + 1] = "unregisterChatFilters"
      end,
      registerChatFilters = function()
        calls[#calls + 1] = "registerChatFilters"
      end,
    }
    local EventBridge = {
      UnregisterLiveEvents = function(_frame)
        calls[#calls + 1] = "UnregisterLiveEvents"
      end,
      UnregisterSuspendableLifecycleEvents = function(_frame)
        calls[#calls + 1] = "UnregisterSuspendableLifecycleEvents"
      end,
      RegisterLiveEvents = function(_frame)
        calls[#calls + 1] = "RegisterLiveEvents"
      end,
      RegisterSuspendableLifecycleEvents = function(_frame)
        calls[#calls + 1] = "RegisterSuspendableLifecycleEvents"
      end,
    }
    local printed = {}
    local savedSuspended = _G._wmSuspended

    MythicSuspendController.Attach(runtime, {
      Bootstrap = Bootstrap,
      mythicPauseNotice = "Whispers are paused in Mythic content. Incoming and outgoing messages will resume after you leave.",
      isWindowVisible = function()
        calls[#calls + 1] = "isWindowVisible"
        return true
      end,
      setWindowVisible = function(visible)
        calls[#calls + 1] = "setWindowVisible:" .. tostring(visible)
      end,
      refreshWindow = function()
        calls[#calls + 1] = "refreshWindow"
      end,
      getEventBridge = function()
        return EventBridge
      end,
      print = function(message)
        printed[#printed + 1] = message
      end,
    })

    assert(type(runtime.suspend) == "function", "Attach should assign runtime.suspend")
    assert(type(runtime.resume) == "function", "Attach should assign runtime.resume")

    runtime.suspend()

    assert(
      runtime.messagingNotice == "Whispers are paused in Mythic content. Incoming and outgoing messages will resume after you leave.",
      "suspend should set the mythic pause notice"
    )
    assert(Bootstrap._wasVisibleBeforeMythic == true, "suspend should capture previous window visibility")
    assert(_G._wmSuspended == true, "suspend should set the global suspended flag")
    assert(
      table.concat(calls, ",")
        == "isWindowVisible,setWindowVisible:false,unregisterChatFilters,UnregisterLiveEvents,UnregisterSuspendableLifecycleEvents",
      "suspend should hide window, unregister chat filters, then unregister event bridge hooks"
    )
    assert(
      printed[1] == "|cff888888[WhisperMessenger]|r Suspended for mythic content. Whispers will resume when you leave.",
      "suspend should print the existing pause message"
    )

    calls = {}
    runtime.resume()

    assert(runtime.messagingNotice == nil, "resume should clear the mythic pause notice")
    assert(_G._wmSuspended == nil, "resume should clear the global suspended flag")
    assert(Bootstrap._wasVisibleBeforeMythic == nil, "resume should clear the remembered visibility flag")
    assert(
      table.concat(calls, ",") == "RegisterLiveEvents,RegisterSuspendableLifecycleEvents,registerChatFilters,setWindowVisible:true,refreshWindow",
      "resume should restore event bridge hooks before chat filters, then show and refresh the window"
    )
    assert(printed[2] == "|cff888888[WhisperMessenger]|r Resumed. Whispers are active again.", "resume should print the existing resume message")

    _G._wmSuspended = savedSuspended
  end
end
