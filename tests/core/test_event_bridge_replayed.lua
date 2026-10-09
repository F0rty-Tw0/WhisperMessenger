local EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
local Store = require("WhisperMessenger.Model.ConversationStore")

local RECEIVED_AT = 800
local STUBBED_GLOBALS = { "PlaySound", "GetCVar", "SetCVar", "FlashClientIcon", "InCombatLockdown", "C_Timer" }

local function newRuntime(settings)
  return {
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    localProfileId = "me",
    now = function()
      return 1000
    end,
    availabilityByGUID = {},
    pendingOutgoing = {},
    accountState = { settings = settings or {} },
    bnetApi = {},
  }
end

local function replayWhisper(runtime, refreshWindow, eventName)
  return EventBridge.RouteReplayedEvent(
    runtime,
    refreshWindow,
    eventName or "CHAT_MSG_WHISPER",
    RECEIVED_AT,
    "held hello",
    "Arthas-Area52",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    40,
    "Player-1-ABC"
  )
end

return function()
  local saved = {}
  for _, name in ipairs(STUBBED_GLOBALS) do
    saved[name] = rawget(_G, name)
  end
  local sounds, flashes = 0, 0
  rawset(_G, "PlaySound", function()
    sounds = sounds + 1
  end)
  rawset(_G, "GetCVar", function()
    return "1"
  end)
  rawset(_G, "SetCVar", function() end)
  rawset(_G, "FlashClientIcon", function()
    flashes = flashes + 1
  end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  _G.C_Timer = {
    After = function(_delay, fn)
      fn()
    end,
  }

  -- test_replayed_whisper_makes_no_sound_or_auto_open

  do
    sounds, flashes = 0, 0
    local autoOpens = 0
    local runtime = newRuntime({ playSoundOnWhisper = true, autoOpenIncoming = true })
    runtime.onAutoOpen = function()
      autoOpens = autoOpens + 1
    end
    replayWhisper(runtime, nil)
    assert(sounds == 0, "replayed whisper must not play a sound, got " .. sounds)
    assert(flashes == 0, "replayed whisper must not flash the taskbar, got " .. flashes)
    assert(autoOpens == 0, "replayed whisper must not auto-open, got " .. autoOpens)
  end

  -- test_replayed_whisper_does_not_set_reply_key

  do
    local runtime = newRuntime()
    runtime.lastIncomingWhisperKey = "wow::WOW::previous-realm"
    replayWhisper(runtime, nil)
    assert(runtime.lastIncomingWhisperKey == "wow::WOW::previous-realm", "replay must not move the reply key")
  end

  -- test_replayed_whisper_does_not_refresh_per_message

  do
    local refreshes = 0
    replayWhisper(newRuntime(), function()
      refreshes = refreshes + 1
    end)
    assert(refreshes == 0, "replay must not refresh per message, got " .. refreshes)
  end

  -- test_replayed_returns_result_and_meta

  do
    local result, meta = replayWhisper(newRuntime(), nil)
    assert(result ~= nil and result.conversationKey == "wow::WOW::arthas-area52", "replay must return the conversation")
    assert(result.messages[1].sentAt == RECEIVED_AT, "replay must store the received time")
    assert(type(meta) == "table", "replay must return the router meta")
  end

  -- test_replayed_inform_no_outgoing_auto_open

  do
    local outgoingOpens = 0
    local runtime = newRuntime({ autoOpenOutgoing = true })
    runtime.onAutoOpenOutgoing = function()
      outgoingOpens = outgoingOpens + 1
    end
    local result = replayWhisper(runtime, nil, "CHAT_MSG_WHISPER_INFORM")
    assert(result ~= nil and result.messages[1].direction == "out", "setup: replayed inform should be stored as outgoing")
    assert(outgoingOpens == 0, "replayed inform must not auto-open, got " .. outgoingOpens)
  end

  -- test_replayed_bnet_payload_carries_resolved_account

  do
    local runtime = newRuntime()
    runtime.bnetApi = {
      GetAccountInfoByID = function(id)
        if id == 12 then
          return { bnetAccountID = 12, battleTag = "Friend#1234", accountName = "|Ks1|k", isOnline = true }
        end
      end,
    }
    local result =
      EventBridge.RouteReplayedEvent(runtime, nil, "CHAT_MSG_BN_WHISPER", RECEIVED_AT, "hi", "|Ks1|k", "", "", "", "", "", "", "", "", 7, nil, 12)
    assert(result ~= nil, "replayed BNet whisper must be stored")
    assert(string.find(result.conversationKey, "bnet::", 1, true) == 1, "stored under a BNet key, got " .. tostring(result.conversationKey))
    assert(result.bnetAccountID == 12, "stored conversation must be the friend's, got " .. tostring(result.bnetAccountID))
  end

  for _, name in ipairs(STUBBED_GLOBALS) do
    rawset(_G, name, saved[name])
  end
end
