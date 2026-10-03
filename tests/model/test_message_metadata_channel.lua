local Store = require("WhisperMessenger.Model.ConversationStore")

-- A channel chat is titled after the channel: a sender's line must not
-- rename it or give it that sender's guid.
return function()
  -- test_channel_line_keeps_title_and_guid
  do
    local store = Store.New({ maxMessagesPerConversation = 50 })
    local key = "channel::arthas-area52::trade"
    Store.EnsureConversation(store, key)
    local conversation = store.conversations[key]
    conversation.channel = "CHANNEL"
    conversation.displayName = "Trade"
    Store.AppendIncoming(store, key, {
      id = "1",
      kind = "user",
      direction = "in",
      text = "WTS ore",
      sentAt = 10,
      playerName = "Seller-Area52",
      guid = "Player-1-SELLER",
      channel = "CHANNEL",
    }, false)
    assert(conversation.displayName == "Trade", "the sender does not rename the channel chat, got " .. tostring(conversation.displayName))
    assert(conversation.guid == nil, "the channel chat takes no sender guid")
  end

  -- test_whisper_line_still_updates_contact
  do
    local store = Store.New({ maxMessagesPerConversation = 50 })
    local key = "arthas-area52::WOW::jaina"
    Store.AppendIncoming(store, key, {
      id = "1",
      kind = "user",
      direction = "in",
      text = "hi",
      sentAt = 10,
      playerName = "Jaina",
      guid = "Player-1-JAINA",
      channel = "WOW",
    }, false)
    assert(
      store.conversations[key].displayName == "Jaina" and store.conversations[key].guid == "Player-1-JAINA",
      "whispers keep updating the contact"
    )
  end
end
