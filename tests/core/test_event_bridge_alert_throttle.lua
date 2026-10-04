local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

-- A long whisper lands as several whispers within a second, before anything
-- says they belong together, so a conversation alerts at most once per ~2s.
-- Only the noise is throttled: every whisper is still stored and counted.

local function whisper(runtime, sender, guid)
  EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_WHISPER", "part", sender or "Arthas", "", "", "", "", "", "", "", "", 1, guid or "Player-1-ABC")
end

return function()
  local flashes, sounds, autoOpens
  local clock = { value = 100 }

  local function setup()
    flashes, sounds, autoOpens = 0, 0, 0
    clock.value = 100
    rawset(_G, "FlashClientIcon", function()
      flashes = flashes + 1
    end)
    rawset(_G, "PlaySound", function()
      sounds = sounds + 1
    end)
    rawset(_G, "InCombatLockdown", function()
      return false
    end)
    _G.C_Timer = { After = function() end }
    return {
      store = { conversations = {}, config = {} },
      localProfileId = "me",
      now = function()
        return clock.value
      end,
      availabilityByGUID = {},
      pendingOutgoing = {},
      accountState = { settings = { playSoundOnWhisper = true, autoOpenIncoming = true } },
      onAutoOpen = function()
        autoOpens = autoOpens + 1
      end,
    }
  end

  -- test_four_parts_within_two_seconds_alert_once
  do
    local runtime = setup()
    for index = 1, 4 do
      clock.value = 100 + (index - 1) * 0.5
      whisper(runtime)
    end
    assert(sounds == 1 and flashes == 1 and autoOpens == 1, "one alert, got " .. sounds .. "/" .. flashes .. "/" .. autoOpens)
    local _, conversation = next(runtime.store.conversations)
    assert(conversation ~= nil, "conversation stored")
    assert(#conversation.messages == 4 and conversation.unreadCount == 4, "every whisper stored and unread")
  end

  -- test_whisper_after_the_window_alerts_again
  do
    local runtime = setup()
    whisper(runtime)
    clock.value = 102
    whisper(runtime)
    assert(sounds == 2 and flashes == 2, "second alert after 2s, got " .. sounds)
  end

  -- test_other_conversations_are_not_throttled
  do
    local runtime = setup()
    whisper(runtime, "Arthas", "Player-1-ABC")
    whisper(runtime, "Jaina", "Player-1-DEF")
    assert(sounds == 2 and flashes == 2, "each conversation alerts, got " .. sounds)
  end

  rawset(_G, "FlashClientIcon", nil)
  rawset(_G, "PlaySound", nil)
  rawset(_G, "InCombatLockdown", nil)
  _G.C_Timer = nil
end
