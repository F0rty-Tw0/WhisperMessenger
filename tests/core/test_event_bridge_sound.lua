local FakeUI = require("tests.helpers.fake_ui")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

return function()
  -- -----------------------------------------------------------------------
  -- test_incoming_whisper_plays_sound_when_enabled
  -- -----------------------------------------------------------------------
  do
    local soundPlayed = nil
    _G.PlaySound = function(soundId)
      soundPlayed = soundId
    end

    local runtime = {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      accountState = { settings = { playSoundOnWhisper = true } },
    }

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_WHISPER",
      "hello",
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

    assert(
      soundPlayed == 7355,
      "test_incoming_whisper_plays_sound_when_enabled: expected sound 7355, got " .. tostring(soundPlayed)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_incoming_whisper_no_sound_when_disabled
  -- -----------------------------------------------------------------------
  do
    local soundPlayed = nil
    _G.PlaySound = function(soundId)
      soundPlayed = soundId
    end

    local runtime = {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      accountState = { settings = { playSoundOnWhisper = false } },
    }

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_WHISPER",
      "hello",
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

    assert(
      soundPlayed == nil,
      "test_incoming_whisper_no_sound_when_disabled: expected no sound, got " .. tostring(soundPlayed)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_outgoing_whisper_does_not_play_sound
  -- -----------------------------------------------------------------------
  do
    local soundPlayed = nil
    _G.PlaySound = function(soundId)
      soundPlayed = soundId
    end

    local runtime = {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return 100
      end,
      availabilityByGUID = {},
      pendingOutgoing = {},
      accountState = { settings = { playSoundOnWhisper = true } },
    }

    EventBridge.RouteLiveEvent(
      runtime,
      nil,
      "CHAT_MSG_WHISPER_INFORM",
      "hello",
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

    assert(
      soundPlayed == nil,
      "test_outgoing_whisper_does_not_play_sound: expected no sound, got " .. tostring(soundPlayed)
    )
  end

  _G.PlaySound = nil
end
