local FakeUI = require("tests.helpers.fake_ui")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local ConversationStore = require("WhisperMessenger.Model.ConversationStore")

return function()
  -- Stub globals needed by SoundPlayer
  rawset(_G, "PlaySound", function() end)
  rawset(_G, "GetCVar", function()
    return "1"
  end)
  rawset(_G, "SetCVar", function() end)
  _G.C_Timer = {
    After = function(_delay, fn)
      fn()
    end,
  }

  -- test_message_recorded_during_combat

  do
    rawset(_G, "InCombatLockdown", function()
      return true
    end)

    local store = ConversationStore.New()
    local runtime = {
      store = store,
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      accountState = {
        settings = {
          playSoundOnWhisper = true,
          autoOpenIncoming = true,
          autoOpenOutgoing = true,
        },
      },
    }

    local autoOpenCalled = false
    runtime.onAutoOpen = function()
      autoOpenCalled = true
    end

    local refreshed = false
    local function refreshWindow()
      refreshed = true
    end

    EventBridge.RouteLiveEvent(
      runtime,
      refreshWindow,
      "CHAT_MSG_WHISPER",
      "Hello from combat!",
      "Arthas",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      1,
      "Player-1-ABC"
    )

    -- Auto-open should NOT fire during combat
    assert(autoOpenCalled == false, "test_combat_recording: auto-open should not fire during combat")

    -- But lastIncomingWhisperKey should be tracked
    assert(runtime.lastIncomingWhisperKey ~= nil, "test_combat_recording: lastIncomingWhisperKey should be set")

    -- refreshWindow should still be called
    assert(refreshed == true, "test_combat_recording: refreshWindow should still be called during combat")

    -- The message should be stored in the conversation
    local conversationKey = runtime.lastIncomingWhisperKey
    local conversation = store.conversations[conversationKey]
    assert(conversation ~= nil, "test_combat_recording: conversation should exist after combat whisper")
    assert(
      #conversation.messages > 0,
      "test_combat_recording: conversation should have messages, got " .. #conversation.messages
    )
    assert(
      conversation.messages[1].text == "Hello from combat!",
      "test_combat_recording: message text should match, got " .. tostring(conversation.messages[1].text)
    )
    assert(
      conversation.unreadCount > 0,
      "test_combat_recording: unreadCount should be > 0, got " .. tostring(conversation.unreadCount)
    )
  end

  -- test_message_recorded_out_of_combat

  do
    rawset(_G, "InCombatLockdown", function()
      return false
    end)

    local store = ConversationStore.New()
    local runtime = {
      store = store,
      localProfileId = "me",
      now = function()
        return 200
      end,
      availabilityByGUID = {},
      accountState = {
        settings = {
          playSoundOnWhisper = false,
          autoOpenIncoming = true,
          autoOpenOutgoing = true,
        },
      },
    }

    local autoOpenKey = nil
    runtime.onAutoOpen = function(key)
      autoOpenKey = key
    end

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_WHISPER",
      "Hello outside combat!",
      "Jaina",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      "",
      2,
      "Player-2-DEF"
    )

    -- Auto-open should fire out of combat
    assert(autoOpenKey ~= nil, "test_ooc_recording: auto-open should fire out of combat")

    -- Message should be stored
    local conversation = store.conversations[autoOpenKey]
    assert(conversation ~= nil, "test_ooc_recording: conversation should exist")
    assert(#conversation.messages > 0, "test_ooc_recording: conversation should have messages")
    assert(conversation.messages[1].text == "Hello outside combat!", "test_ooc_recording: message text should match")
  end

  rawset(_G, "PlaySound", nil)
  rawset(_G, "GetCVar", nil)
  rawset(_G, "SetCVar", nil)
  _G.C_Timer = nil
  rawset(_G, "InCombatLockdown", nil)
end
