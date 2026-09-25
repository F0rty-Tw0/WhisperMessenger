local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")

-- Incoming-whisper alerts: taskbar flash (default on) and per-conversation
-- mute silencing sound, flash and auto-open.

local function whisper(runtime, eventName)
  EventBridge.RouteLiveEvent(runtime, nil, eventName or "CHAT_MSG_WHISPER", "hello", "Arthas", "", "", "", "", "", "", "", "", 1, "Player-1-ABC")
end

local function onlyConversation(runtime)
  local _, conversation = next(runtime.store.conversations)
  return conversation
end

return function()
  local flashes, sounds, autoOpens

  local function setup(settings)
    flashes, sounds, autoOpens = 0, 0, 0
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
        return 100
      end,
      availabilityByGUID = {},
      pendingOutgoing = {},
      accountState = { settings = settings },
      onAutoOpen = function()
        autoOpens = autoOpens + 1
      end,
    }
  end

  -- test_incoming_whisper_flashes_taskbar_by_default
  do
    local runtime = setup({})
    whisper(runtime)
    assert(flashes == 1, "flash is on by default, got " .. flashes)
  end

  -- test_incoming_bnet_whisper_flashes_taskbar
  do
    local runtime = setup({})
    EventBridge.RouteLiveEvent(runtime, nil, "CHAT_MSG_BN_WHISPER", "hi", "Friend#1", "", "", "", "", "", "", "", "", 1, nil, 42)
    assert(flashes == 1, "battle.net whisper flashes, got " .. flashes)
  end

  -- test_flash_setting_off_disables_flash
  do
    local runtime = setup({ flashTaskbarOnWhisper = false })
    whisper(runtime)
    assert(flashes == 0, "flash disabled by setting")
  end

  -- test_outgoing_whisper_does_not_flash
  do
    local runtime = setup({})
    whisper(runtime, "CHAT_MSG_WHISPER_INFORM")
    assert(flashes == 0, "outgoing never flashes")
  end

  -- test_missing_flash_api_is_harmless
  do
    local runtime = setup({})
    rawset(_G, "FlashClientIcon", nil)
    whisper(runtime)
    assert(onlyConversation(runtime) ~= nil, "whisper still stored without the flash api")
  end

  -- test_muted_conversation_is_silent_but_still_counts_unread
  do
    local runtime = setup({ playSoundOnWhisper = true, autoOpenIncoming = true })
    whisper(runtime)
    assert(flashes == 1 and sounds == 1 and autoOpens == 1, "first whisper alerts normally")
    local conversation = onlyConversation(runtime)
    conversation.muted = true
    whisper(runtime)
    assert(flashes == 1, "muted: no flash")
    assert(sounds == 1, "muted: no sound")
    assert(autoOpens == 1, "muted: no auto-open")
    assert(conversation.unreadCount == 2, "muted whispers still count as unread")
    assert(runtime.lastIncomingWhisperKey ~= nil, "reply target still follows muted whispers")
  end

  rawset(_G, "FlashClientIcon", nil)
  rawset(_G, "PlaySound", nil)
  rawset(_G, "InCombatLockdown", nil)
  _G.C_Timer = nil
end
