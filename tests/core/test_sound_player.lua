local SoundPlayer = require("WhisperMessenger.Core.SoundPlayer")

return function()
  local originalPlaySound = rawget(_G, "PlaySound")
  local originalCSound = rawget(_G, "C_Sound")
  local originalGetCVar = rawget(_G, "GetCVar")
  local originalSetCVar = rawget(_G, "SetCVar")
  local originalCTimer = rawget(_G, "C_Timer")

  local function restoreGlobals()
    rawset(_G, "PlaySound", originalPlaySound)
    rawset(_G, "C_Sound", originalCSound)
    rawset(_G, "GetCVar", originalGetCVar)
    rawset(_G, "SetCVar", originalSetCVar)
    rawset(_G, "C_Timer", originalCTimer)
  end

  local function installCVarMocks(cvars, calls)
    rawset(_G, "GetCVar", function(key)
      calls[#calls + 1] = { action = "get", key = key }
      return cvars[key]
    end)
    rawset(_G, "SetCVar", function(key, value)
      calls[#calls + 1] = { action = "set", key = key, value = value }
      cvars[key] = value
    end)
  end

  local ok, err = pcall(function()
    -- test_supports_volume_detects_callable_native_api

    rawset(_G, "C_Sound", {
      PlaySoundWithOptions = function() end,
    })
    assert(SoundPlayer.SupportsVolume() == true, "test_supports_volume_detects_callable_native_api: expected native support")

    rawset(_G, "C_Sound", {})
    assert(SoundPlayer.SupportsVolume() == false, "test_supports_volume_detects_callable_native_api: expected missing function to be unsupported")

    rawset(_G, "C_Sound", nil)
    assert(SoundPlayer.SupportsVolume() == false, "test_supports_volume_detects_callable_native_api: expected missing table to be unsupported")

    -- test_normalize_volume_defaults_invalid_values_and_clamps_finite_values

    assert(SoundPlayer.NormalizeVolume(nil) == 1, "test_normalize_volume: expected missing value to default to 1")
    assert(SoundPlayer.NormalizeVolume("1") == 1, "test_normalize_volume: expected non-number to default to 1")
    assert(SoundPlayer.NormalizeVolume(0 / 0) == 1, "test_normalize_volume: expected NaN to default to 1")
    assert(SoundPlayer.NormalizeVolume(math.huge) == 1, "test_normalize_volume: expected positive infinity to default to 1")
    assert(SoundPlayer.NormalizeVolume(-math.huge) == 1, "test_normalize_volume: expected negative infinity to default to 1")
    assert(SoundPlayer.NormalizeVolume(-0.25) == 0, "test_normalize_volume: expected negative value to clamp to 0")
    assert(SoundPlayer.NormalizeVolume(2) == 1, "test_normalize_volume: expected value above 1 to clamp to 1")
    assert(SoundPlayer.NormalizeVolume(0.4) == 0.4, "test_normalize_volume: expected in-range value unchanged")

    -- test_native_play_reads_enabled_audio_without_mutating_or_scheduling

    local enabledCalls = {}
    installCVarMocks({
      Sound_EnableAllSound = "1",
      Sound_EnableSFX = "1",
    }, enabledCalls)
    rawset(_G, "C_Timer", {
      After = function()
        error("test_native_play_reads_enabled_audio_without_mutating_or_scheduling: timer must not be scheduled")
      end,
    })
    rawset(_G, "C_Sound", {
      PlaySoundWithOptions = function(options)
        enabledCalls[#enabledCalls + 1] = { action = "native", options = options }
      end,
    })
    rawset(_G, "PlaySound", function()
      error("test_native_play_reads_enabled_audio_without_mutating_or_scheduling: legacy PlaySound must not be called")
    end)

    SoundPlayer.Play({ notificationSound = "ping", notificationVolume = 0.4 })

    assert(#enabledCalls == 3, "test_native_play_reads_enabled_audio_without_mutating_or_scheduling: expected two reads and one native call")
    assert(
      enabledCalls[1].action == "get" and enabledCalls[1].key == "Sound_EnableAllSound",
      "test_native_play_reads_enabled_audio_without_mutating_or_scheduling: expected all-sound read"
    )
    assert(
      enabledCalls[2].action == "get" and enabledCalls[2].key == "Sound_EnableSFX",
      "test_native_play_reads_enabled_audio_without_mutating_or_scheduling: expected SFX read"
    )
    assert(enabledCalls[3].action == "native", "test_native_play_reads_enabled_audio_without_mutating_or_scheduling: expected native playback")
    assert(enabledCalls[3].options.soundKitID == 5274, "test_native_play_reads_enabled_audio_without_mutating_or_scheduling: expected soundId 5274")
    assert(
      enabledCalls[3].options.volumeOverride == 0.4,
      "test_native_play_reads_enabled_audio_without_mutating_or_scheduling: expected override 0.4"
    )

    -- test_disabled_native_audio_is_enabled_for_playback_then_restored

    local nativeCalls = {}
    local nativeTimer
    installCVarMocks({
      Sound_EnableAllSound = "0",
      Sound_EnableSFX = "0",
    }, nativeCalls)
    rawset(_G, "C_Timer", {
      After = function(delay, callback)
        nativeCalls[#nativeCalls + 1] = { action = "timer", delay = delay }
        nativeTimer = callback
      end,
    })
    rawset(_G, "C_Sound", {
      PlaySoundWithOptions = function(options)
        nativeCalls[#nativeCalls + 1] = { action = "native", options = options }
      end,
    })

    SoundPlayer.Play({ notificationSound = "chime", notificationVolume = 0.25 })

    assert(#nativeCalls == 6, "test_disabled_native_audio_is_enabled_for_playback_then_restored: expected reads, enables, playback, and timer")
    assert(
      nativeCalls[3].action == "set" and nativeCalls[3].key == "Sound_EnableAllSound" and nativeCalls[3].value == "1",
      "test_disabled_native_audio_is_enabled_for_playback_then_restored: expected all-sound enable"
    )
    assert(
      nativeCalls[4].action == "set" and nativeCalls[4].key == "Sound_EnableSFX" and nativeCalls[4].value == "1",
      "test_disabled_native_audio_is_enabled_for_playback_then_restored: expected SFX enable"
    )
    assert(
      nativeCalls[5].action == "native",
      "test_disabled_native_audio_is_enabled_for_playback_then_restored: expected native playback after enables"
    )
    assert(nativeCalls[5].options.soundKitID == 6674, "test_disabled_native_audio_is_enabled_for_playback_then_restored: expected soundId 6674")
    assert(nativeCalls[5].options.volumeOverride == 0.25, "test_disabled_native_audio_is_enabled_for_playback_then_restored: expected override 0.25")
    assert(
      nativeCalls[6].action == "timer" and nativeCalls[6].delay == 0.5,
      "test_disabled_native_audio_is_enabled_for_playback_then_restored: expected restoration timer"
    )
    assert(type(nativeTimer) == "function", "test_disabled_native_audio_is_enabled_for_playback_then_restored: expected restoration callback")

    nativeTimer()

    assert(#nativeCalls == 8, "test_disabled_native_audio_is_enabled_for_playback_then_restored: expected both CVars restored")
    assert(
      nativeCalls[7].action == "set" and nativeCalls[7].key == "Sound_EnableAllSound" and nativeCalls[7].value == "0",
      "test_disabled_native_audio_is_enabled_for_playback_then_restored: expected all-sound restoration"
    )
    assert(
      nativeCalls[8].action == "set" and nativeCalls[8].key == "Sound_EnableSFX" and nativeCalls[8].value == "0",
      "test_disabled_native_audio_is_enabled_for_playback_then_restored: expected SFX restoration"
    )

    -- test_disabled_legacy_audio_is_enabled_for_playback_then_restored

    local legacyCalls = {}
    local legacyTimer
    installCVarMocks({
      Sound_EnableAllSound = "0",
      Sound_EnableSFX = "0",
    }, legacyCalls)
    rawset(_G, "C_Timer", {
      After = function(delay, callback)
        legacyCalls[#legacyCalls + 1] = { action = "timer", delay = delay }
        legacyTimer = callback
      end,
    })
    rawset(_G, "C_Sound", nil)
    rawset(_G, "PlaySound", function(soundId, channel)
      legacyCalls[#legacyCalls + 1] = { action = "legacy", soundId = soundId, channel = channel }
    end)

    SoundPlayer.Preview("ping", 0)

    assert(#legacyCalls == 6, "test_disabled_legacy_audio_is_enabled_for_playback_then_restored: expected reads, enables, playback, and timer")
    assert(
      legacyCalls[3].action == "set" and legacyCalls[3].key == "Sound_EnableAllSound" and legacyCalls[3].value == "1",
      "test_disabled_legacy_audio_is_enabled_for_playback_then_restored: expected all-sound enable"
    )
    assert(
      legacyCalls[4].action == "set" and legacyCalls[4].key == "Sound_EnableSFX" and legacyCalls[4].value == "1",
      "test_disabled_legacy_audio_is_enabled_for_playback_then_restored: expected SFX enable"
    )
    assert(
      legacyCalls[5].action == "legacy" and legacyCalls[5].soundId == 5274 and legacyCalls[5].channel == "Master",
      "test_disabled_legacy_audio_is_enabled_for_playback_then_restored: expected Master playback after enables"
    )
    assert(
      legacyCalls[6].action == "timer" and legacyCalls[6].delay == 0.5,
      "test_disabled_legacy_audio_is_enabled_for_playback_then_restored: expected restoration timer"
    )

    legacyTimer()

    assert(#legacyCalls == 8, "test_disabled_legacy_audio_is_enabled_for_playback_then_restored: expected both CVars restored")
    assert(
      legacyCalls[7].action == "set" and legacyCalls[7].key == "Sound_EnableAllSound" and legacyCalls[7].value == "0",
      "test_disabled_legacy_audio_is_enabled_for_playback_then_restored: expected all-sound restoration"
    )
    assert(
      legacyCalls[8].action == "set" and legacyCalls[8].key == "Sound_EnableSFX" and legacyCalls[8].value == "0",
      "test_disabled_legacy_audio_is_enabled_for_playback_then_restored: expected SFX restoration"
    )

    -- test_only_disabled_cvar_is_changed_and_restored

    local partialCalls = {}
    local partialTimer
    installCVarMocks({
      Sound_EnableAllSound = "1",
      Sound_EnableSFX = "0",
    }, partialCalls)
    rawset(_G, "C_Timer", {
      After = function(delay, callback)
        partialCalls[#partialCalls + 1] = { action = "timer", delay = delay }
        partialTimer = callback
      end,
    })
    rawset(_G, "C_Sound", {
      PlaySoundWithOptions = function(options)
        partialCalls[#partialCalls + 1] = { action = "native", options = options }
      end,
    })

    SoundPlayer.Play({ notificationSound = "whisper", notificationVolume = 1 })

    assert(#partialCalls == 5, "test_only_disabled_cvar_is_changed_and_restored: expected one enable, playback, and timer")
    assert(
      partialCalls[3].action == "set" and partialCalls[3].key == "Sound_EnableSFX" and partialCalls[3].value == "1",
      "test_only_disabled_cvar_is_changed_and_restored: expected only SFX enable"
    )
    assert(partialCalls[4].action == "native", "test_only_disabled_cvar_is_changed_and_restored: expected native playback")
    assert(
      partialCalls[5].action == "timer" and partialCalls[5].delay == 0.5,
      "test_only_disabled_cvar_is_changed_and_restored: expected restoration timer"
    )

    partialTimer()

    assert(#partialCalls == 6, "test_only_disabled_cvar_is_changed_and_restored: expected only SFX restoration")
    assert(
      partialCalls[6].action == "set" and partialCalls[6].key == "Sound_EnableSFX" and partialCalls[6].value == "0",
      "test_only_disabled_cvar_is_changed_and_restored: expected SFX restoration"
    )

    -- test_overlapping_muted_plays_renew_the_cvar_lease

    local overlapCalls = {}
    local overlapTimers = {}
    local overlapCVars = {
      Sound_EnableAllSound = "0",
      Sound_EnableSFX = "0",
    }
    installCVarMocks(overlapCVars, overlapCalls)
    rawset(_G, "C_Timer", {
      After = function(delay, callback)
        overlapCalls[#overlapCalls + 1] = { action = "timer", delay = delay }
        overlapTimers[#overlapTimers + 1] = callback
      end,
    })
    rawset(_G, "C_Sound", {
      PlaySoundWithOptions = function(options)
        overlapCalls[#overlapCalls + 1] = { action = "native", options = options }
      end,
    })

    SoundPlayer.Play({ notificationSound = "ping", notificationVolume = 0.4 })
    SoundPlayer.Play({ notificationSound = "chime", notificationVolume = 0.25 })

    assert(#overlapTimers == 2, "test_overlapping_muted_plays_renew_the_cvar_lease: expected a timer for each successful play")
    assert(overlapTimers[1] ~= overlapTimers[2], "test_overlapping_muted_plays_renew_the_cvar_lease: expected separate callbacks")
    overlapTimers[1]()
    assert(
      overlapCVars.Sound_EnableAllSound == "1" and overlapCVars.Sound_EnableSFX == "1",
      "test_overlapping_muted_plays_renew_the_cvar_lease: expected stale callback to leave CVars enabled"
    )
    overlapTimers[2]()
    assert(
      overlapCVars.Sound_EnableAllSound == "0" and overlapCVars.Sound_EnableSFX == "0",
      "test_overlapping_muted_plays_renew_the_cvar_lease: expected newest callback to restore CVars"
    )
    assert(#overlapCalls == 10, "test_overlapping_muted_plays_renew_the_cvar_lease: expected one enable and one restoration per CVar")

    -- test_failed_first_muted_play_restores_cvvars_without_a_timer

    local failedPlayCalls = {}
    local failedPlayTimers = {}
    local failedPlayCVars = {
      Sound_EnableAllSound = "0",
      Sound_EnableSFX = "0",
    }
    installCVarMocks(failedPlayCVars, failedPlayCalls)
    rawset(_G, "C_Timer", {
      After = function(delay, callback)
        failedPlayCalls[#failedPlayCalls + 1] = { action = "timer", delay = delay }
        failedPlayTimers[#failedPlayTimers + 1] = callback
      end,
    })
    rawset(_G, "C_Sound", {
      PlaySoundWithOptions = function()
        error("test_failed_first_muted_play_restores_cvvars_without_a_timer: expected playback failure")
      end,
    })

    local failedPlayOk, failedPlayError = pcall(function()
      SoundPlayer.Play({ notificationSound = "ping", notificationVolume = 0.4 })
    end)

    assert(failedPlayOk == false, "test_failed_first_muted_play_restores_cvvars_without_a_timer: expected playback error")
    assert(
      string.find(failedPlayError, "expected playback failure", 1, true) ~= nil,
      "test_failed_first_muted_play_restores_cvvars_without_a_timer: expected original playback error"
    )
    assert(
      failedPlayCVars.Sound_EnableAllSound == "0" and failedPlayCVars.Sound_EnableSFX == "0",
      "test_failed_first_muted_play_restores_cvvars_without_a_timer: expected immediate CVar restoration"
    )
    assert(#failedPlayTimers == 0, "test_failed_first_muted_play_restores_cvvars_without_a_timer: expected no timer")
    assert(#failedPlayCalls == 6, "test_failed_first_muted_play_restores_cvvars_without_a_timer: expected enables and immediate restoration")

    -- test_zero_native_volume_skips_before_audio_cvar_work

    rawset(_G, "GetCVar", function()
      error("test_zero_native_volume_skips_before_audio_cvar_work: GetCVar must not be called")
    end)
    rawset(_G, "SetCVar", function()
      error("test_zero_native_volume_skips_before_audio_cvar_work: SetCVar must not be called")
    end)
    rawset(_G, "C_Timer", {
      After = function()
        error("test_zero_native_volume_skips_before_audio_cvar_work: timer must not be scheduled")
      end,
    })
    rawset(_G, "C_Sound", {
      PlaySoundWithOptions = function()
        error("test_zero_native_volume_skips_before_audio_cvar_work: native playback must not occur")
      end,
    })

    SoundPlayer.Play({ notificationSound = "ping", notificationVolume = 0 })
  end)

  restoreGlobals()
  assert(ok, err)
end
