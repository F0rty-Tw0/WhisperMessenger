local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local Store = require("WhisperMessenger.Model.ConversationStore")
local IncomingAlerts = require("WhisperMessenger.Core.Bootstrap.EventBridge.IncomingAlerts")
local OnlineWatch = require("WhisperMessenger.Model.OnlineWatch")
local LivePresence = require("WhisperMessenger.Model.LivePresence")

local NOW = 1000
local GONE = "me::WOW::jaina"
local KEPT = "me::WOW::thrall"

-- A real runtime with two whisper chats; session state is written through
-- the modules that own it, never by poking the maps.
local function build()
  local characterState = { activeConversationKey = GONE }
  local runtime = RuntimeFactory.CreateRuntimeState({ conversations = {} }, characterState, "me", {
    now = function()
      return NOW
    end,
  })
  Store.EnsureConversation(runtime.store, GONE)
  Store.EnsureConversation(runtime.store, KEPT)
  return runtime, characterState
end

return function()
  -- test_removing_conversation_clears_alert_throttle
  do
    local runtime = build()
    assert(IncomingAlerts.Throttled(runtime, GONE, NOW) == false, "the first alert passes and is recorded")
    assert(IncomingAlerts.Throttled(runtime, KEPT, NOW) == false, "the first alert passes and is recorded")

    Store.Remove(runtime.store, GONE)

    assert(runtime.lastAlertAtByConversation[GONE] == nil, "a removed chat keeps no alert time")
    assert(IncomingAlerts.Throttled(runtime, KEPT, NOW + 1) == true, "a chat that still exists stays throttled inside the window")
  end

  -- test_removing_conversation_clears_online_watch
  do
    local runtime = build()
    OnlineWatch.Observe(runtime, GONE, false)
    OnlineWatch.Observe(runtime, KEPT, false)

    Store.Remove(runtime.store, GONE)

    assert(runtime.onlineWatch[GONE] == nil, "a removed chat keeps no online state")
    assert(OnlineWatch.Observe(runtime, KEPT, true) == true, "a chat that still exists keeps its last seen state")
  end

  -- test_removing_conversation_clears_live_presence_peer
  do
    local runtime = build()
    assert(LivePresence.RecordPeer(runtime, GONE) == true)
    assert(LivePresence.RecordPeer(runtime, KEPT) == true)

    Store.Remove(runtime.store, GONE)

    assert(runtime.livePresencePeers[GONE] == nil, "a removed chat keeps no addon-peer flag")
    assert(LivePresence.HasPeer(runtime, KEPT) == true, "a chat that still exists keeps its addon-peer flag")
  end

  -- test_removing_conversation_while_session_maps_are_empty
  do
    local runtime = build()
    assert(next(runtime.lastAlertAtByConversation) == nil and next(runtime.onlineWatch) == nil and next(runtime.livePresencePeers) == nil)
    Store.Remove(runtime.store, GONE)
    assert(runtime.store.conversations[GONE] == nil, "removal works while the session maps are still empty")
  end

  -- test_capacity_and_retention_removals_clear_session_maps_too
  do
    local runtime = build()
    IncomingAlerts.Throttled(runtime, GONE, NOW)
    OnlineWatch.Observe(runtime, GONE, true)
    LivePresence.RecordPeer(runtime, GONE)
    runtime.store.conversations[GONE].lastActivityAt = 1
    runtime.store.conversations[KEPT].lastActivityAt = NOW
    runtime.activeConversationKey = nil

    Store.ApplyRetention(runtime.store, NOW + 1000000, nil)

    assert(runtime.store.conversations[GONE] == nil, "the stale chat expires")
    assert(runtime.lastAlertAtByConversation[GONE] == nil, "expiry clears the alert time")
    assert(runtime.onlineWatch[GONE] == nil, "expiry clears the online state")
    assert(runtime.livePresencePeers[GONE] == nil, "expiry clears the addon-peer flag")
  end

  -- test_removing_selected_conversation_clears_selection_through_the_hook
  do
    local runtime, characterState = build()
    runtime.lastIncomingWhisperKey = GONE

    Store.Remove(runtime.store, GONE)

    assert(runtime.activeConversationKey == nil, "the runtime selection is cleared")
    assert(characterState.activeConversationKey == nil, "the saved selection is cleared")
    assert(runtime.lastIncomingWhisperKey == nil, "reply-to-last no longer targets it")
  end

  -- test_removing_another_conversation_keeps_selection
  do
    local runtime, characterState = build()
    runtime.lastIncomingWhisperKey = GONE

    Store.Remove(runtime.store, KEPT)

    assert(runtime.activeConversationKey == GONE and characterState.activeConversationKey == GONE, "the selection stays")
    assert(runtime.lastIncomingWhisperKey == GONE, "the reply target stays")
  end
end
