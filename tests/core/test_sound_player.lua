local SoundPlayer = require("WhisperMessenger.Core.SoundPlayer")

return function()

  -- test_play_uses_correct_sound_id_for_key

  do
    local playedId, playedChannel
    rawset(_G, "PlaySound", function(soundId, channel)
      playedId = soundId
      playedChannel = channel
    end)
    rawset(_G, "GetCVar", function()
      return "1"
    end)
    rawset(_G, "SetCVar", function() end)
    _G.C_Timer = {
      After = function(_delay, fn)
        fn()
      end,
    }

    SoundPlayer.Play({ notificationSound = "ping" })

    assert(
      playedId == 5274,
      "test_play_uses_correct_sound_id_for_key: expected soundId 5274, got " .. tostring(playedId)
    )
    assert(
      playedChannel == "Master",
      "test_play_uses_correct_sound_id_for_key: expected channel Master, got " .. tostring(playedChannel)
    )
  end

  -- test_play_defaults_to_whisper_sound

  do
    local playedId
    rawset(_G, "PlaySound", function(soundId, _channel)
      playedId = soundId
    end)
    rawset(_G, "GetCVar", function()
      return "1"
    end)
    rawset(_G, "SetCVar", function() end)
    _G.C_Timer = {
      After = function(_delay, fn)
        fn()
      end,
    }

    SoundPlayer.Play({})

    assert(playedId == 3081, "test_play_defaults_to_whisper_sound: expected soundId 3081, got " .. tostring(playedId))
  end

  -- test_play_does_not_toggle_global_sound_cvars_when_muted

  do
    local setCvarCalled = false
    local timerScheduled = false
    rawset(_G, "PlaySound", function() end)
    rawset(_G, "GetCVar", function(key)
      if key == "Sound_EnableAllSound" or key == "Sound_EnableSFX" then
        return "0"
      end
      return "1"
    end)
    rawset(_G, "SetCVar", function()
      setCvarCalled = true
    end)
    _G.C_Timer = {
      After = function(_delay, _fn)
        timerScheduled = true
      end,
    }

    SoundPlayer.Play({})

    assert(
      setCvarCalled == false,
      "test_play_does_not_toggle_global_sound_cvars_when_muted: should not call SetCVar while playing notification sound"
    )
    assert(
      timerScheduled == false,
      "test_play_does_not_toggle_global_sound_cvars_when_muted: should not schedule C_Timer.After when not changing CVars"
    )
  end

  -- test_play_skips_cvar_when_audio_already_enabled

  do
    local setCvarCalled = false
    rawset(_G, "PlaySound", function() end)
    rawset(_G, "GetCVar", function()
      return "1"
    end)
    rawset(_G, "SetCVar", function()
      setCvarCalled = true
    end)
    _G.C_Timer = {
      After = function(_delay, fn)
        fn()
      end,
    }

    SoundPlayer.Play({})

    assert(
      setCvarCalled == false,
      "test_play_skips_cvar_when_audio_already_enabled: should not call SetCVar when audio is already enabled"
    )
  end

  -- test_preview_plays_sound_directly_without_cvar_manipulation

  do
    local playedId, playedChannel
    local setCvarCalled = false
    rawset(_G, "PlaySound", function(soundId, channel)
      playedId = soundId
      playedChannel = channel
    end)
    rawset(_G, "SetCVar", function()
      setCvarCalled = true
    end)

    SoundPlayer.Preview("ping")

    assert(playedId == 5274, "test_preview: expected soundId 5274, got " .. tostring(playedId))
    assert(playedChannel == "Master", "test_preview: expected channel Master, got " .. tostring(playedChannel))
    assert(setCvarCalled == false, "test_preview: should not manipulate CVars")
  end

  -- cleanup
  rawset(_G, "PlaySound", nil)
  rawset(_G, "GetCVar", nil)
  rawset(_G, "SetCVar", nil)
  _G.C_Timer = nil
end
