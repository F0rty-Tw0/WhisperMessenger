local IncomingAlerts = require("WhisperMessenger.Core.Bootstrap.EventBridge.IncomingAlerts")
local OnlineNotify = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.OnlineNotify")

-- "Mute all sounds" silences every alert sound; the taskbar flash still fires.

local WHISPER_ID = 3081
local PING_ID = 5274
local CHIME_ID = 6674

return function()
  local played = {}
  rawset(_G, "PlaySound", function(soundId)
    played[#played + 1] = soundId
  end)
  rawset(_G, "FlashClientIcon", nil)

  local function reset()
    for index = #played, 1, -1 do
      played[index] = nil
    end
  end

  -- test_muted_whisper_is_silent
  do
    reset()
    IncomingAlerts.Notify({ muteAllSounds = true, playSoundOnWhisper = true }, nil)
    assert(#played == 0, "muted whisper plays nothing, got " .. tostring(played[1]))
  end

  -- test_muted_mention_is_silent
  do
    reset()
    IncomingAlerts.Notify({ muteAllSounds = true, playSoundOnWhisper = true, mentionSound = "orb" }, "mention")
    assert(#played == 0, "muted mention plays nothing, got " .. tostring(played[1]))
  end

  -- test_muted_online_notice_is_silent
  do
    reset()
    local runtime = { accountState = { settings = { muteAllSounds = true, playSoundOnWhisper = true } } }
    OnlineNotify.Announce(runtime, { displayName = "Arthas" }, "%s is online.")
    assert(#played == 0, "muted online or zone notice plays nothing, got " .. tostring(played[1]))
  end

  -- test_muted_request_is_silent
  do
    reset()
    IncomingAlerts.PlayRequestSound({ muteAllSounds = true, requestSound = "ping" })
    assert(#played == 0, "muted request plays nothing, got " .. tostring(played[1]))
  end

  -- test_muted_sent_is_silent
  do
    reset()
    IncomingAlerts.PlaySentSound({ muteAllSounds = true, playSoundOnSend = true })
    assert(#played == 0, "muted sent whisper plays nothing, got " .. tostring(played[1]))
  end

  -- test_muted_notify_still_flashes
  do
    reset()
    local flashes = 0
    rawset(_G, "FlashClientIcon", function()
      flashes = flashes + 1
    end)
    IncomingAlerts.Notify({ muteAllSounds = true, playSoundOnWhisper = true })
    rawset(_G, "FlashClientIcon", nil)
    assert(flashes == 1, "mute leaves the taskbar flash alone, got " .. tostring(flashes))
  end

  -- test_unmuted_sounds_play
  do
    reset()
    IncomingAlerts.Notify({ muteAllSounds = false, playSoundOnWhisper = true })
    IncomingAlerts.PlayRequestSound({ muteAllSounds = false })
    IncomingAlerts.PlaySentSound({ muteAllSounds = false, playSoundOnSend = true })
    assert(
      #played == 3 and played[1] == WHISPER_ID and played[2] == PING_ID and played[3] == CHIME_ID,
      "mute off plays every sound as before, got " .. table.concat(played, ",")
    )
  end
end
