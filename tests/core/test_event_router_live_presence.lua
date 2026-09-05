local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local LivePresence = require("WhisperMessenger.Model.LivePresence")
local Router = require("WhisperMessenger.Core.EventRouter")

local function newState(nowRef)
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return nowRef.value
    end,
  }
end

local function addonEvent(text)
  return { prefix = "WMRX", text = text, channel = "WHISPER", playerName = "Arthas-Area52" }
end

local function whisperEvent(text, lineID)
  return { text = text, playerName = "Arthas-Area52", guid = "Player-1", lineID = lineID }
end

return function()
  local key = "wow::WOW::arthas-area52"

  -- test_typing_payload_marks_conversation_typing_and_peer
  do
    local now = { value = 100 }
    local state = newState(now)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent("hi", 1))
    local result, meta = Router.HandleEvent(state, "CHAT_MSG_ADDON", addonEvent(LivePresence.EncodeTyping(true)))
    assert(result and result.conversationKey == key, "typing returns the conversation so the window refreshes")
    assert(meta and meta.presence == "typing" and meta.typingActive == true, "meta describes typing start")
    assert(LivePresence.IsTyping(state, key, now.value), "conversation is typing")
    assert(LivePresence.HasPeer(state, key), "typing sender is a known addon peer")
    assert(#state.store.conversations[key].messages == 1, "typing adds no messages")

    local _, stopMeta = Router.HandleEvent(state, "CHAT_MSG_ADDON", addonEvent(LivePresence.EncodeTyping(false)))
    assert(stopMeta and stopMeta.typingActive == false, "meta describes typing stop")
    assert(not LivePresence.IsTyping(state, key, now.value), "stop clears typing")
  end

  -- test_identity_payload_marks_peer_and_refreshes_when_it_pairs
  do
    local now = { value = 200 }
    local state = newState(now)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent("hello there", 2))
    local result = Router.HandleEvent(state, "CHAT_MSG_ADDON", addonEvent(Protocol.EncodeIdentity("wire1", "hello there")))
    assert(LivePresence.HasPeer(state, key), "identity sender is a known addon peer")
    assert(result and result.conversationKey == key, "paired identity returns the conversation so receipts can go out")
    assert(state.store.conversations[key].messages[1].wireId == "wire1", "identity paired with the whisper")
  end

  -- test_seen_payload_marks_outgoing_message_seen
  do
    local now = { value = 300 }
    local state = newState(now)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent("hi", 3))
    Store.AppendOutgoing(state.store, key, { direction = "out", kind = "user", wireId = "out1", text = "yo", sentAt = 290 })
    local result, meta = Router.HandleEvent(state, "CHAT_MSG_ADDON", addonEvent(LivePresence.EncodeSeen("out1")))
    assert(result and result.conversationKey == key, "seen returns the conversation")
    assert(meta and meta.presence == "seen", "meta describes seen")
    assert(state.store.conversations[key].messages[2].seenAt == 300, "outgoing message marked seen")
  end

  -- test_presence_from_unknown_sender_is_ignored
  do
    local now = { value = 400 }
    local state = newState(now)
    local result = Router.HandleEvent(state, "CHAT_MSG_ADDON", { prefix = "WMRX", text = LivePresence.EncodeTyping(true), channel = "WHISPER" })
    assert(result == nil, "no player name means no conversation")
  end

  -- test_group_channel_presence_is_ignored
  do
    local now = { value = 500 }
    local state = newState(now)
    local result = Router.HandleEvent(
      state,
      "CHAT_MSG_ADDON",
      { prefix = "WMRX", text = LivePresence.EncodeTyping(true), channel = "PARTY", playerName = "Arthas-Area52" }
    )
    assert(result == nil, "group channel typing ignored")
    assert(not LivePresence.IsTyping(state, key, now.value), "group typing does not mark whisper conversation")
  end

  -- test_battle_net_typing_resolves_bnet_conversation
  do
    local now = { value = 600 }
    local state = newState(now)
    local whisper = Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", {
      text = "hey",
      playerName = "Jaina",
      channel = "BN",
      bnetAccountID = 77,
      gameAccountID = 9001,
      battleTag = "Jaina#1234",
      lineID = 10,
    })
    assert(whisper and whisper.conversationKey, "bnet whisper creates a conversation")
    local bnKey = whisper.conversationKey
    local result = Router.HandleEvent(state, "BN_CHAT_MSG_ADDON", {
      prefix = "WMRX",
      text = LivePresence.EncodeTyping(true),
      channel = "WHISPER",
      bnetAccountID = 77,
      gameAccountID = 9001,
    })
    assert(result and result.conversationKey == bnKey, "bnet typing resolves to the bnet conversation")
    assert(LivePresence.IsTyping(state, bnKey, now.value), "bnet conversation is typing")
    assert(LivePresence.HasPeer(state, bnKey), "bnet friend is a known peer")
  end
end
