local MythicSuspendController = require("WhisperMessenger.Core.Bootstrap.MythicSuspendController")

return function()

  -- test_resume_clears_stale_last_incoming_whisper_key

  -- We did NOT capture whispers during M+ (LIVE_EVENTS were unregistered),
  -- so any runtime.lastIncomingWhisperKey still set is pre-M+ stale. Resume
  -- must clear it so a post-M+ /r in our messenger does not route to a
  -- pre-M+ conversation.
  do
    local runtime = {
      lastIncomingWhisperKey = "me::WOW::pre-mythic-target",
    }
    local Bootstrap = {
      _loadFrame = {},
      unregisterChatFilters = function() end,
      registerChatFilters = function() end,
    }
    local EventBridge = {
      UnregisterLiveEvents = function() end,
      UnregisterSuspendableLifecycleEvents = function() end,
      RegisterLiveEvents = function() end,
      RegisterSuspendableLifecycleEvents = function() end,
    }

    MythicSuspendController.Attach(runtime, {
      Bootstrap = Bootstrap,
      isWindowVisible = function()
        return false
      end,
      setWindowVisible = function() end,
      refreshWindow = function() end,
      getEventBridge = function()
        return EventBridge
      end,
      print = function() end,
    })

    runtime.suspend()
    runtime.resume()

    assert(
      runtime.lastIncomingWhisperKey == nil,
      "resume must clear stale lastIncomingWhisperKey so post-M+ /r does not route to a pre-M+ conversation"
    )
  end

  -- test_resume_does_not_touch_blizzard_last_tell

  -- Writing to ChatEdit_SetLastTellTarget from addon code — even via
  -- securecall — attributes caller taint to the upvalue slots inside
  -- chatEditLastTell and propagates taint into MessageEventHandler on the
  -- NEXT incoming whisper. Resume must NOT call it.
  do
    local runtime = { lastIncomingWhisperKey = nil }
    local Bootstrap = {
      _loadFrame = {},
      unregisterChatFilters = function() end,
      registerChatFilters = function() end,
    }
    local EventBridge = {
      UnregisterLiveEvents = function() end,
      UnregisterSuspendableLifecycleEvents = function() end,
      RegisterLiveEvents = function() end,
      RegisterSuspendableLifecycleEvents = function() end,
    }

    local setLastTellCalls = 0
    local savedSetLastTell = _G.ChatEdit_SetLastTellTarget

    rawset(_G, "ChatEdit_SetLastTellTarget", function()
      setLastTellCalls = setLastTellCalls + 1
    end)

    MythicSuspendController.Attach(runtime, {
      Bootstrap = Bootstrap,
      isWindowVisible = function()
        return false
      end,
      setWindowVisible = function() end,
      refreshWindow = function() end,
      getEventBridge = function()
        return EventBridge
      end,
      print = function() end,
    })

    runtime.suspend()
    runtime.resume()

    assert(
      setLastTellCalls == 0,
      "resume must NOT call ChatEdit_SetLastTellTarget (direct write from our stack taints chatEditLastTell), got "
        .. setLastTellCalls
        .. " calls"
    )

    rawset(_G, "ChatEdit_SetLastTellTarget", savedSetLastTell)
  end
end
