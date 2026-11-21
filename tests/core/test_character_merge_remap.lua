local CharacterMergeRemap = require("WhisperMessenger.Core.Bootstrap.CharacterMergeRemap")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local PendingQueue = require("WhisperMessenger.Model.MessageReactions.PendingQueue")
local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")
local World = require("tests.helpers.character_merge_world")

-- When a character's chat folds into their Battle.net friend's chat, the
-- session state held under the character's key moves to the friend's key,
-- so nothing is left pointing at a chat that no longer exists.
local K = World.K
local B = World.B
local OTHER = "wow::WOW::thrall-area52"

local function fresh()
  local characterState = {}
  local runtime = RuntimeFactory.CreateRuntimeState({ conversations = {} }, characterState, "me", {
    now = function()
      return 1000
    end,
  })
  return runtime, characterState
end

local function composerWithReply(selected, target)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "parent", nil)
  parent:SetSize(600, 50)
  local sent = {}
  local composer = Composer.Create(factory, parent, selected, function(payload)
    sent[#sent + 1] = payload
    return true
  end)
  composer.setReply(K, target)
  return composer, sent
end

return function()
  -- test_open_chat_follows_the_merge
  do
    local runtime, characterState = fresh()
    runtime.activeConversationKey = K
    characterState.activeConversationKey = K
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.activeConversationKey == B, "the open chat is the friend's chat, got " .. tostring(runtime.activeConversationKey))
    assert(characterState.activeConversationKey == B, "the saved open chat follows too")
  end

  -- test_reply_to_last_follows_the_merge
  do
    local runtime = fresh()
    runtime.lastIncomingWhisperKey = K
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.lastIncomingWhisperKey == B, "the reply key answers the friend's chat")
  end

  -- test_unread_divider_follows_the_merge
  do
    local runtime = fresh()
    runtime.unreadDivider = { conversationKey = K, message = { text = "hi" } }
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.unreadDivider.conversationKey == B, "the New messages divider stays on the merged chat")
  end

  -- test_online_watch_follows_the_merge
  do
    local runtime = fresh()
    runtime.onlineWatch[K] = true
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.onlineWatch[B] == true and runtime.onlineWatch[K] == nil, "notify-when-online moves to the friend's chat")
  end

  -- test_pending_sends_join_the_friend_queue_in_order
  do
    local runtime = fresh()
    runtime.pendingOutgoing[B] = { { text = "to the app", createdAt = 900 } }
    runtime.pendingOutgoing[K] = { { text = "to the character", createdAt = 950 }, { text = "second part", createdAt = 950 } }
    CharacterMergeRemap.Apply(runtime, K, B)
    local queue = runtime.pendingOutgoing[B]
    assert(runtime.pendingOutgoing[K] == nil, "no pending send is left on the character key")
    assert(#queue == 3, "both queues are kept, got " .. #queue)
    assert(
      queue[1].text == "to the app" and queue[2].text == "to the character" and queue[3].text == "second part",
      "the friend's sends first, then the character's, in order"
    )
  end

  -- test_pending_sends_move_when_the_friend_has_none
  do
    local runtime = fresh()
    local entry = { text = "to the character", createdAt = 950 }
    runtime.pendingOutgoing[K] = { entry }
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(
      runtime.pendingOutgoing[B][1] == entry and runtime.pendingOutgoing[K] == nil,
      "the character's pending send now waits in the friend's chat"
    )
  end

  -- test_send_status_follows_the_merge
  do
    local runtime = fresh()
    local status = { status = "Send failed" }
    runtime.sendStatusByConversation[K] = status
    runtime.sendStatusByConversation[OTHER] = { status = "Offline" }
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.sendStatusByConversation[B] == status and runtime.sendStatusByConversation[K] == nil, "the send status moves to the friend's chat")
    assert(runtime.sendStatusByConversation[OTHER].status == "Offline", "another chat's status is untouched")
  end

  -- test_friend_chat_keeps_its_own_value
  do
    local runtime = fresh()
    local own = { status = "Offline" }
    runtime.sendStatusByConversation[B] = own
    runtime.sendStatusByConversation[K] = { status = "Send failed" }
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.sendStatusByConversation[B] == own, "the friend's chat keeps its own status")
    assert(runtime.sendStatusByConversation[K] == nil, "the character's status is dropped")
  end

  -- test_typing_indicator_is_dropped_on_merge
  do
    local runtime = fresh()
    runtime.typingByConversation[K] = 1010
    CharacterMergeRemap.Apply(runtime, K, B)
    -- No expiry timer runs for the friend's chat, so a moved indicator would
    -- stay up; an incoming whisper that merges the chat ends the typing
    -- anyway. A merge made by my own outgoing whisper can hide a peer who is
    -- still typing for up to ~3 s, until their next typing packet.
    assert(runtime.typingByConversation[K] == nil, "no typing indicator is left on the character key")
    assert(runtime.typingByConversation[B] == nil, "the friend's chat shows no typing without a timer behind it")
  end

  -- test_friend_typing_indicator_is_kept
  do
    local runtime = fresh()
    runtime.typingByConversation[B] = 1008
    runtime.typingByConversation[K] = 1010
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.typingByConversation[B] == 1008, "the friend's own typing indicator stays")
  end

  -- test_own_typing_follows_the_merge
  do
    local runtime = fresh()
    runtime.typingOut = { active = true, conversationKey = K }
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.typingOut.conversationKey == B, "the stopped-typing notice goes to the friend's chat")
  end

  -- test_typing_expiry_flag_leaves_the_character_key
  do
    local runtime = fresh()
    runtime.typingExpiryPending[K] = true
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.typingExpiryPending[K] == nil, "no expiry flag is left on the character key")
    assert(runtime.typingExpiryPending[B] == nil, "no flag is set on the friend's chat: no timer runs for it")
  end

  -- test_addon_peer_follows_the_merge
  do
    local runtime = fresh()
    runtime.livePresencePeers[K] = true
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.livePresencePeers[B] == true and runtime.livePresencePeers[K] == nil, "the addon peer mark moves to the friend's chat")
  end

  -- test_alert_throttle_follows_the_merge
  do
    local runtime = fresh()
    runtime.lastAlertAtByConversation[K] = 990
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(
      runtime.lastAlertAtByConversation[B] == 990 and runtime.lastAlertAtByConversation[K] == nil,
      "the alert throttle moves to the friend's chat"
    )
  end

  -- test_collapse_index_drops_the_character_key
  do
    local runtime = fresh()
    runtime.collapseIndex[K] = {}
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.collapseIndex[K] == nil, "the character's duplicate index is dropped")
  end

  -- test_pending_reactions_follow_the_merge
  do
    local runtime = fresh()
    local queues = PendingQueue.RuntimeState(runtime)
    -- A character sender's queue is keyed by the character's chat key.
    queues.identityMetadata[K] = { { conversationKey = K, recordedAt = 990 } }
    queues.operations[OTHER] = { { conversationKey = OTHER, recordedAt = 990 } }
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(queues.identityMetadata[K] == nil, "no waiting reaction is left under the character's sender key")
    assert(queues.identityMetadata[B][1].conversationKey == B, "a waiting reaction now waits for the friend's chat")
    assert(queues.operations[OTHER][1].conversationKey == OTHER, "another chat's waiting reaction is untouched")
  end

  -- test_staged_reply_link_follows_the_merge
  do
    local runtime = fresh()
    runtime.replyLinksStaged = { { conversationKey = K, link = {}, recordedAt = 990 } }
    CharacterMergeRemap.Apply(runtime, K, B)
    assert(runtime.replyLinksStaged[1].conversationKey == B, "a waiting quote now waits for the friend's chat")
  end

  -- test_reply_target_follows_the_merge
  do
    local selected = { conversationKey = K, displayName = World.NAME, channel = "WOW" }
    local target = { wireId = "w1", direction = "in", snippet = "hi" }
    local composer, sent = composerWithReply(selected, target)
    local runtime = fresh()
    runtime.window = { composer = composer }
    CharacterMergeRemap.Apply(runtime, K, B)
    selected.conversationKey = B
    composer.input:SetText("hello")
    composer.input.scripts.OnEnterPressed(composer.input)
    assert(sent[1].replyTo == target, "the reply the player picked carries over to the friend's chat")
  end

  -- test_same_key_changes_nothing
  do
    local runtime = fresh()
    runtime.sendStatusByConversation[K] = { status = "Send failed" }
    CharacterMergeRemap.Apply(runtime, K, K)
    assert(runtime.sendStatusByConversation[K] ~= nil, "a merge into the same key keeps the chat's status")
  end
end
