local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local IncomingAlerts = require("WhisperMessenger.Core.Bootstrap.EventBridge.IncomingAlerts")
local OnlineWatch = require("WhisperMessenger.Model.OnlineWatch")
local LivePresence = require("WhisperMessenger.Model.LivePresence")
local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

local NOW = 1000
local WHISPER = "me::WOW::jaina"
local GROUP = "me::PARTY::party"
local CHANNEL = "channel::me::trade"
local GUID = "Player-jaina"

local function conversation(key, channel, guid)
  return { conversationKey = key, channel = channel, guid = guid, messages = { { id = "1", text = "hi", sentAt = NOW } }, lastActivityAt = NOW }
end

-- A real runtime holding a whisper, a group chat and a channel chat, with the
-- whisper selected and session state recorded for it.
local function build(clearOnLogout, activeKey)
  local accountState = {
    settings = { clearOnLogout = clearOnLogout },
    conversations = {
      [WHISPER] = conversation(WHISPER, "WOW", GUID),
      [GROUP] = conversation(GROUP, "PARTY"),
      [CHANNEL] = conversation(CHANNEL, "CHANNEL"),
    },
  }
  local characterState = { activeConversationKey = activeKey or WHISPER }
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, characterState, "me", {
    now = function()
      return NOW
    end,
  })
  runtime.lastIncomingWhisperKey = WHISPER
  runtime.sendStatusByConversation[WHISPER] = { status = "sent" }
  runtime.collapseIndex[CHANNEL] = {}
  runtime.availabilityByGUID[GUID] = { status = "CanWhisper" }
  IncomingAlerts.Throttled(runtime, WHISPER, NOW)
  OnlineWatch.Observe(runtime, WHISPER, true)
  LivePresence.RecordPeer(runtime, WHISPER)
  -- Channel lines kept to show above a new whisper from the same player.
  ChannelMessageStore.Record(runtime.channelMessageStore, "Thrall-Realm", "WTS sword", "Trade", NOW, 2)
  ChannelMessageStore.Record(runtime.channelMessageStore, "Jaina-Realm", "LF healer", "LookingForGroup", NOW, 26)
  return runtime, accountState, characterState
end

return function()
  -- test_logout_with_setting_on_removes_saved_channel_lines
  do
    local runtime, accountState = build(true)
    local saved = accountState.channelMessages
    assert(saved == runtime.channelMessageStore and saved.entryCount == 2, "fixture: two channel lines are saved")

    Presence.handlePlayerLogout({ runtime = runtime })

    assert(accountState.channelMessages == saved, "the saved table itself is emptied")
    assert(next(saved.entries) == nil and saved.entryCount == 0, "no channel line is left to save")
    assert(ChannelMessageStore.GetLatest(saved, "thrall-realm", NOW) == nil, "a cleared line is not found again")
  end

  -- test_logout_with_setting_off_keeps_saved_channel_lines
  do
    local runtime, accountState = build(false)

    Presence.handlePlayerLogout({ runtime = runtime })

    assert(accountState.channelMessages.entryCount == 2, "channel lines stay")
    assert(ChannelMessageStore.GetLatest(accountState.channelMessages, "thrall-realm", NOW) ~= nil, "a kept line is still found")
  end

  -- test_logout_with_setting_on_and_no_channel_store_still_clears_conversations
  do
    local runtime, accountState = build(true)
    runtime.channelMessageStore = nil

    assert(Presence.handlePlayerLogout({ runtime = runtime }) == true)

    assert(next(accountState.conversations) == nil, "conversations are cleared without a channel store")
  end

  -- test_logout_with_setting_on_removes_whisper_group_and_channel_conversations
  do
    local runtime, accountState = build(true)
    local conversations = accountState.conversations

    assert(Presence.handlePlayerLogout({ runtime = runtime }) == true)

    assert(conversations[WHISPER] == nil, "whisper history is gone")
    assert(conversations[GROUP] == nil, "group chat history is gone")
    assert(conversations[CHANNEL] == nil, "channel chat history is gone")
    assert(accountState.conversations == conversations and next(conversations) == nil, "the saved table itself is emptied")
  end

  -- test_logout_with_setting_on_runs_the_removal_hook_for_every_conversation
  do
    local runtime = build(true)
    local forgotten = {}
    runtime.onConversationRemoved = function(key)
      forgotten[key] = true
    end

    Presence.handlePlayerLogout({ runtime = runtime })

    assert(forgotten[WHISPER] and forgotten[GROUP] and forgotten[CHANNEL], "each chat goes through the removal hook")
    assert(runtime.sendStatusByConversation[WHISPER] == nil, "send status is released")
    assert(runtime.collapseIndex[CHANNEL] == nil, "collapse entries are released")
    assert(runtime.availabilityByGUID[GUID] == nil, "the GUID cache is released")
    assert(runtime.lastAlertAtByConversation[WHISPER] == nil, "the alert time is released")
    assert(runtime.onlineWatch[WHISPER] == nil, "the online state is released")
    assert(runtime.livePresencePeers[WHISPER] == nil, "the addon-peer flag is released")
  end

  -- test_logout_with_setting_on_clears_selection_and_reply_target
  do
    local runtime, _, characterState = build(true)

    Presence.handlePlayerLogout({ runtime = runtime })

    assert(runtime.activeConversationKey == nil, "runtime selection is cleared")
    assert(characterState.activeConversationKey == nil, "saved selection is cleared")
    assert(runtime.lastIncomingWhisperKey == nil, "reply target is cleared")
  end

  -- test_logout_with_setting_on_clears_a_saved_selection_whose_chat_is_already_gone
  -- A chat that expired while offline leaves the saved selection naming it.
  do
    local runtime, _, characterState = build(true, "me::WOW::expired")
    assert(runtime.activeConversationKey == "me::WOW::expired")

    Presence.handlePlayerLogout({ runtime = runtime })

    assert(runtime.activeConversationKey == nil, "runtime selection is cleared")
    assert(characterState.activeConversationKey == nil, "saved selection is cleared")
  end

  -- test_logout_with_setting_off_clears_nothing
  do
    local runtime, accountState, characterState = build(false)
    runtime.onConversationRemoved = function()
      error("nothing may be removed with the setting off")
    end

    assert(Presence.handlePlayerLogout({ runtime = runtime }) == true)

    assert(accountState.conversations[WHISPER] ~= nil, "whisper history stays")
    assert(accountState.conversations[GROUP] ~= nil, "group chat history stays")
    assert(accountState.conversations[CHANNEL] ~= nil, "channel chat history stays")
    assert(runtime.activeConversationKey == WHISPER and characterState.activeConversationKey == WHISPER, "selection stays")
    assert(runtime.lastIncomingWhisperKey == WHISPER, "reply target stays")
    assert(runtime.sendStatusByConversation[WHISPER] ~= nil and runtime.collapseIndex[CHANNEL] ~= nil, "session state stays")
    assert(runtime.lastAlertAtByConversation[WHISPER] ~= nil and runtime.onlineWatch[WHISPER] ~= nil, "session maps stay")
  end

  -- test_logout_without_a_runtime_does_nothing
  do
    assert(Presence.handlePlayerLogout({}) == true)
  end
end
