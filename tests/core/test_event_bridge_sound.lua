local FakeUI = require("tests.helpers.fake_ui")
local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

return function()
  -- -----------------------------------------------------------------------
  -- Helpers: stub globals needed by SoundPlayer (called via EventBridge)
  -- -----------------------------------------------------------------------
  local function stubSoundGlobals()
    local soundPlayed = nil
    _G.PlaySound = function(soundId, _channel)
      soundPlayed = soundId
    end
    _G.GetCVar = function()
      return "1"
    end
    _G.SetCVar = function() end
    _G.C_Timer = {
      After = function(_delay, fn)
        fn()
      end,
    }
    return function()
      return soundPlayed
    end
  end

  -- -----------------------------------------------------------------------
  -- test_incoming_whisper_plays_sound_when_enabled
  -- -----------------------------------------------------------------------
  do
    local getSoundPlayed = stubSoundGlobals()

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

    local soundPlayed = getSoundPlayed()
    assert(
      soundPlayed == 3081,
      "test_incoming_whisper_plays_sound_when_enabled: expected sound 3081, got " .. tostring(soundPlayed)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_incoming_whisper_no_sound_when_disabled
  -- -----------------------------------------------------------------------
  do
    local getSoundPlayed = stubSoundGlobals()

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

    local soundPlayed = getSoundPlayed()
    assert(
      soundPlayed == nil,
      "test_incoming_whisper_no_sound_when_disabled: expected no sound, got " .. tostring(soundPlayed)
    )
  end

  -- -----------------------------------------------------------------------
  -- test_outgoing_whisper_does_not_play_sound
  -- -----------------------------------------------------------------------
  do
    local getSoundPlayed = stubSoundGlobals()

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

    local soundPlayed = getSoundPlayed()
    assert(
      soundPlayed == nil,
      "test_outgoing_whisper_does_not_play_sound: expected no sound, got " .. tostring(soundPlayed)
    )
  end

  _G.PlaySound = nil
  _G.GetCVar = nil
  _G.SetCVar = nil
  _G.C_Timer = nil
end
