local IncomingAlerts = require("WhisperMessenger.Core.Bootstrap.EventBridge.IncomingAlerts")

-- Mentions play their own pick (falling back to the whisper pick); whispers
-- sent from the addon play the sent pick when the player turned it on.

local WHISPER_ID = 3081
local CHIME_ID = 6674
local BELL_ID = 5275
local ORB_ID = 32585

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

  -- test_mention_plays_mention_sound
  do
    reset()
    IncomingAlerts.Notify({ playSoundOnWhisper = true, mentionSound = "orb", notificationSound = "bell" }, "mention")
    assert(#played == 1 and played[1] == ORB_ID, "mention plays the mention pick, got " .. tostring(played[1]))
  end

  -- test_mention_without_pick_plays_whisper_pick
  do
    reset()
    IncomingAlerts.Notify({ playSoundOnWhisper = true, notificationSound = "bell" }, "mention")
    assert(#played == 1 and played[1] == BELL_ID, "unset mention pick falls back to the whisper pick, got " .. tostring(played[1]))
  end

  -- test_mention_without_any_pick_plays_default
  do
    reset()
    IncomingAlerts.Notify({ playSoundOnWhisper = true }, "mention")
    assert(#played == 1 and played[1] == WHISPER_ID, "no pick at all plays the default, got " .. tostring(played[1]))
  end

  -- test_mention_silent_when_whisper_sound_off
  do
    reset()
    IncomingAlerts.Notify({ playSoundOnWhisper = false, mentionSound = "orb", notificationSound = "bell" }, "mention")
    assert(#played == 0, "whisper sound off silences mentions")
  end

  -- test_whisper_kind_ignores_mention_pick
  do
    reset()
    IncomingAlerts.Notify({ playSoundOnWhisper = true, mentionSound = "orb", notificationSound = "bell" })
    assert(#played == 1 and played[1] == BELL_ID, "a whisper plays the whisper pick, got " .. tostring(played[1]))
  end

  -- test_sent_sound_plays_only_when_toggle_on
  do
    reset()
    IncomingAlerts.PlaySentSound({ sentSound = "orb" })
    IncomingAlerts.PlaySentSound({ playSoundOnSend = false, sentSound = "orb" })
    assert(#played == 0, "sent sound is off unless turned on")
    IncomingAlerts.PlaySentSound({ playSoundOnSend = true, sentSound = "orb" })
    assert(#played == 1 and played[1] == ORB_ID, "toggle on plays the sent pick, got " .. tostring(played[1]))
  end

  -- test_sent_without_pick_plays_chime
  do
    reset()
    IncomingAlerts.PlaySentSound({ playSoundOnSend = true, notificationSound = "bell" })
    assert(#played == 1 and played[1] == CHIME_ID, "unset sent pick plays the chime, got " .. tostring(played[1]))
  end

  -- test_sent_sound_with_nil_settings_is_silent
  do
    reset()
    local ok, err = pcall(IncomingAlerts.PlaySentSound, nil)
    assert(ok, "nil settings must not error: " .. tostring(err))
    assert(#played == 0, "nil settings play nothing")
  end

  rawset(_G, "PlaySound", nil)
end
