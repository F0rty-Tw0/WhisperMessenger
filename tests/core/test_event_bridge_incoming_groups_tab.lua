-- Regression: an incoming whisper must never replace the selected group
-- chat when the messenger is currently on the Groups tab. Switching is only
-- allowed when the Whispers tab is active.

local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

local WHISPER_ARGS = {
  "Hello there",
  "Arthas-Area52",
  "",
  "",
  "Arthas-Area52",
  "",
  0,
  0,
  "",
  0,
  123,
  "Player-1-00000001",
  0,
  false,
}

local function stubGlobals()
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  rawset(_G, "IsInGroup", function()
    return true
  end)
  rawset(_G, "time", function()
    return 1000
  end)
end

return function()
  -- test_incoming_whisper_on_groups_tab_does_not_call_onAutoOpen
  do
    stubGlobals()
    local autoOpenCalls = {}
    local runtime = {
      store = { conversations = {}, config = {} },
      now = function()
        return 1000
      end,
      accountState = {
        settings = { autoOpenIncoming = true, autoOpenOutgoing = true, playSoundOnWhisper = false },
      },
      localProfileId = "me",
      activeConversationKey = "PARTY::1",
      availabilityByGUID = {},
      pendingOutgoing = {},
      window = {
        getTabMode = function()
          return "groups"
        end,
      },
    }
    runtime.onAutoOpen = function(conversationKey)
      autoOpenCalls[#autoOpenCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(WHISPER_ARGS))

    assert(#autoOpenCalls == 0, "expected zero onAutoOpen calls when on groups tab; got " .. #autoOpenCalls)
    assert(
      runtime.activeConversationKey == "PARTY::1",
      "activeConversationKey must remain on the selected group; got " .. tostring(runtime.activeConversationKey)
    )
    -- lastIncomingWhisperKey is still tracked so /wr still works
    assert(
      runtime.lastIncomingWhisperKey ~= nil,
      "lastIncomingWhisperKey should still track the whisper for later reply"
    )
  end

  -- test_incoming_whisper_on_whispers_tab_still_auto_opens
  do
    stubGlobals()
    local autoOpenCalls = {}
    local runtime = {
      store = { conversations = {}, config = {} },
      now = function()
        return 1000
      end,
      accountState = {
        settings = { autoOpenIncoming = true, autoOpenOutgoing = true, playSoundOnWhisper = false },
      },
      localProfileId = "me",
      activeConversationKey = nil,
      availabilityByGUID = {},
      pendingOutgoing = {},
      window = {
        getTabMode = function()
          return "whispers"
        end,
      },
    }
    runtime.onAutoOpen = function(conversationKey)
      autoOpenCalls[#autoOpenCalls + 1] = conversationKey
    end

    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", table.unpack(WHISPER_ARGS))

    assert(
      #autoOpenCalls == 1,
      "expected onAutoOpen to fire on whispers tab (with autoOpenIncoming on); got " .. #autoOpenCalls
    )
  end
end
