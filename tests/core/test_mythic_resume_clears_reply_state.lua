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
      "resume must NOT call ChatEdit_SetLastTellTarget (direct write from our stack taints chatEditLastTell), got " .. setLastTellCalls .. " calls"
    )

    rawset(_G, "ChatEdit_SetLastTellTarget", savedSetLastTell)
  end

  -- test_resume_scrubs_blizzard_default_chat_whisper_sticky

  -- A whisper received during M+ is handled by Blizzard's default chat. When
  -- the user replies via /r or the R-key, Blizzard sets chatType=WHISPER,
  -- stickyType=WHISPER, tellTarget=Sender on ChatFrame1EditBox. After M+
  -- ends our auto-open poller would see that focused edit box on the next
  -- Enter and re-open the messenger to that conversation.
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

    local attributes = {
      chatType = "WHISPER",
      stickyType = "WHISPER",
      tellTarget = "Jaina",
    }
    local editBox = {
      GetAttribute = function(self, key)
        return attributes[key]
      end,
      SetAttribute = function(self, key, value)
        attributes[key] = value
      end,
      GetText = function()
        return ""
      end,
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
      getNumChatWindows = function()
        return 1
      end,
      getEditBox = function(index)
        if index == 1 then
          return editBox
        end
        return nil
      end,
    })

    runtime.suspend()
    runtime.resume()

    assert(attributes.tellTarget == nil, "resume must clear stale Blizzard tellTarget so post-M+ Enter does not reopen the messenger")
    assert(
      attributes.chatType == "SAY",
      "resume must restore stale WHISPER chatType to a non-whisper fallback (SAY), got " .. tostring(attributes.chatType)
    )
    assert(
      attributes.stickyType == "SAY",
      "resume must restore stale WHISPER stickyType to a non-whisper fallback (SAY), got " .. tostring(attributes.stickyType)
    )
  end
end
