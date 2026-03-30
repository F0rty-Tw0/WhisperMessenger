local SoundPlayer = require("WhisperMessenger.Core.SoundPlayer")

return function()
  -- -----------------------------------------------------------------------
  -- test_play_uses_correct_sound_id_for_key
  -- -----------------------------------------------------------------------
  do
    local playedId, playedChannel
    _G.PlaySound = function(soundId, channel)
      playedId = soundId
      playedChannel = channel
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

  -- -----------------------------------------------------------------------
  -- test_play_defaults_to_whisper_sound
  -- -----------------------------------------------------------------------
  do
    local playedId
    _G.PlaySound = function(soundId, _channel)
      playedId = soundId
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

    SoundPlayer.Play({})

    assert(playedId == 3081, "test_play_defaults_to_whisper_sound: expected soundId 3081, got " .. tostring(playedId))
  end

  -- -----------------------------------------------------------------------
  -- test_play_always_force_enables_audio_when_muted
  -- -----------------------------------------------------------------------
  do
    local setCvarCalls = {}
    local timerCallback = nil
    _G.PlaySound = function() end
    _G.GetCVar = function(key)
      if key == "Sound_EnableAllSound" then
        return "0"
      end
      if key == "Sound_EnableSFX" then
        return "0"
      end
      return "1"
    end
    _G.SetCVar = function(key, val)
      table.insert(setCvarCalls, { key = key, val = val })
    end
    _G.C_Timer = {
      After = function(_delay, fn)
        timerCallback = fn
      end,
    }

    SoundPlayer.Play({})

    -- verify both enable CVars were set to "1"
    local enabledAll, enabledSFX = false, false
    for _, call in ipairs(setCvarCalls) do
      if call.key == "Sound_EnableAllSound" and call.val == "1" then
        enabledAll = true
      end
      if call.key == "Sound_EnableSFX" and call.val == "1" then
        enabledSFX = true
      end
    end
    assert(enabledAll, "test_play_always_force_enables: expected SetCVar('Sound_EnableAllSound', '1')")
    assert(enabledSFX, "test_play_always_force_enables: expected SetCVar('Sound_EnableSFX', '1')")

    -- fire timer and verify restore to "0"
    setCvarCalls = {}
    assert(timerCallback ~= nil, "test_play_always_force_enables: expected C_Timer.After to be called")
    timerCallback()
    local restoredAll, restoredSFX = false, false
    for _, call in ipairs(setCvarCalls) do
      if call.key == "Sound_EnableAllSound" and call.val == "0" then
        restoredAll = true
      end
      if call.key == "Sound_EnableSFX" and call.val == "0" then
        restoredSFX = true
      end
    end
    assert(restoredAll, "test_play_always_force_enables: expected restore SetCVar('Sound_EnableAllSound', '0')")
    assert(restoredSFX, "test_play_always_force_enables: expected restore SetCVar('Sound_EnableSFX', '0')")
  end

  -- -----------------------------------------------------------------------
  -- test_play_skips_cvar_when_audio_already_enabled
  -- -----------------------------------------------------------------------
  do
    local setCvarCalled = false
    _G.PlaySound = function() end
    _G.GetCVar = function()
      return "1"
    end
    _G.SetCVar = function()
      setCvarCalled = true
    end
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

  -- -----------------------------------------------------------------------
  -- test_preview_plays_sound_directly_without_cvar_manipulation
  -- -----------------------------------------------------------------------
  do
    local playedId, playedChannel
    local setCvarCalled = false
    _G.PlaySound = function(soundId, channel)
      playedId = soundId
      playedChannel = channel
    end
    _G.SetCVar = function()
      setCvarCalled = true
    end

    SoundPlayer.Preview("ping")

    assert(playedId == 5274, "test_preview: expected soundId 5274, got " .. tostring(playedId))
    assert(playedChannel == "Master", "test_preview: expected channel Master, got " .. tostring(playedChannel))
    assert(setCvarCalled == false, "test_preview: should not manipulate CVars")
  end

  -- cleanup
  _G.PlaySound = nil
  _G.GetCVar = nil
  _G.SetCVar = nil
  _G.C_Timer = nil
end
