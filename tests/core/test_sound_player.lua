local SoundPlayer = require("WhisperMessenger.Core.SoundPlayer")
local FakeSharedSounds = require("tests.helpers.fake_shared_sounds")

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

    assert(playedId == 5274, "test_play_uses_correct_sound_id_for_key: expected soundId 5274, got " .. tostring(playedId))
    assert(playedChannel == "Master", "test_play_uses_correct_sound_id_for_key: expected channel Master, got " .. tostring(playedChannel))
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

    assert(setCvarCalled == false, "test_play_skips_cvar_when_audio_already_enabled: should not call SetCVar when audio is already enabled")
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

    SoundPlayer.PlayKey("ping")

    assert(playedId == 5274, "test_preview: expected soundId 5274, got " .. tostring(playedId))
    assert(playedChannel == "Master", "test_preview: expected channel Master, got " .. tostring(playedChannel))
    assert(setCvarCalled == false, "test_preview: should not manipulate CVars")
  end

  -- Records PlaySound / PlaySoundFile calls made by fn().
  local function recordPlays(fn)
    local plays = {}
    rawset(_G, "PlaySound", function(soundId, channel)
      plays[#plays + 1] = { api = "PlaySound", sound = soundId, channel = channel }
    end)
    rawset(_G, "PlaySoundFile", function(path, channel)
      plays[#plays + 1] = { api = "PlaySoundFile", sound = path, channel = channel }
    end)
    fn()
    rawset(_G, "PlaySoundFile", nil)
    return plays
  end

  local SHARED = { { "Boom", "Interface\\AddOns\\Media\\boom.ogg" } }

  -- test_preview_shared_media_sound_plays_its_file_on_master
  do
    local plays
    FakeSharedSounds.with(SHARED, function()
      plays = recordPlays(function()
        SoundPlayer.PlayKey(SoundPlayer.SharedMediaKey("Boom"))
      end)
    end)
    assert(#plays == 1 and plays[1].api == "PlaySoundFile", "SharedMedia pick previews through PlaySoundFile")
    assert(plays[1].sound == "Interface\\AddOns\\Media\\boom.ogg" and plays[1].channel == "Master", "plays the fetched file on Master")
  end

  -- test_play_saved_shared_media_sound_plays_its_file
  do
    local plays
    FakeSharedSounds.with(SHARED, function()
      plays = recordPlays(function()
        SoundPlayer.Play({ notificationSound = SoundPlayer.SharedMediaKey("Boom") })
      end)
    end)
    assert(#plays == 1 and plays[1].sound == "Interface\\AddOns\\Media\\boom.ogg", "saved SharedMedia name plays its file")
  end

  -- test_play_missing_shared_media_sound_plays_the_default
  do
    local plays
    FakeSharedSounds.with(SHARED, function()
      plays = recordPlays(function()
        SoundPlayer.Play({ notificationSound = SoundPlayer.SharedMediaKey("Gone") })
      end)
    end)
    assert(#plays == 1 and plays[1].api == "PlaySound" and plays[1].sound == 3081, "a vanished SharedMedia sound falls back to Whisper")
  end

  -- test_play_shared_media_sound_without_shared_media_plays_the_default
  do
    local plays
    FakeSharedSounds.with(nil, function()
      plays = recordPlays(function()
        SoundPlayer.Play({ notificationSound = SoundPlayer.SharedMediaKey("Boom") })
      end)
    end)
    assert(#plays == 1 and plays[1].api == "PlaySound" and plays[1].sound == 3081, "no SharedMedia addon falls back to Whisper")
  end

  -- test_list_shared_sounds_skips_lsm_none
  do
    local names
    FakeSharedSounds.with({ { "None", "Interface\\Quiet.ogg" }, { "Boom", "boom.ogg" } }, function()
      names = SoundPlayer.ListSharedSounds()
    end)
    assert(#names == 1 and names[1] == "Boom", "SharedMedia's silent None entry is not offered")
  end

  -- test_list_shared_sounds_without_shared_media_is_empty
  do
    local names
    FakeSharedSounds.with(nil, function()
      names = SoundPlayer.ListSharedSounds()
    end)
    assert(#names == 0, "no SharedMedia addon lists no shared sounds")
  end

  -- test_raid_warning_sound_shows_its_full_name
  do
    local raidWarning
    for _, sound in ipairs(SoundPlayer.BUILTIN_SOUNDS) do
      if sound.key == "raid_warning" then
        raidWarning = sound
      end
    end
    assert(raidWarning, "saved key raid_warning still exists")
    assert(raidWarning.label == "Raid Warning", "full-width rows spell out Raid Warning, got " .. tostring(raidWarning.label))
  end

  -- cleanup
  rawset(_G, "PlaySound", nil)
  rawset(_G, "GetCVar", nil)
  rawset(_G, "SetCVar", nil)
  _G.C_Timer = nil
end
