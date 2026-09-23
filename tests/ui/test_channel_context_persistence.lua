-- A Trade/channel post shown in an existing whisper conversation is kept in
-- that conversation, so it survives /reload past the 30-minute channel TTL and
-- then follows the whisper history's own retention and deletion.

local ChannelContextMerger = require("WhisperMessenger.UI.ConversationPane.ChannelContextMerger")
local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")
local ConversationStore = require("WhisperMessenger.Model.ConversationStore")

local CHANNEL_TTL = 1800
local MESSAGE_MAX_AGE = 86400
local LINK = "|cffffd000|Htrade:Player-1-0A:2018:164|h[Blacksmithing]|h|r"

local function newStore()
  return ConversationStore.New({ messageMaxAge = MESSAGE_MAX_AGE, conversationMaxAge = MESSAGE_MAX_AGE })
end

local function addConversation(store, key, sentAt)
  ConversationStore.AppendIncoming(store, key, { id = "1", kind = "user", direction = "in", text = "hi", sentAt = sentAt }, false)
  local conversation = store.conversations[key]
  conversation.channel = "WOW"
  return conversation
end

local function merge(channelState, conversation, now)
  local messages = conversation and conversation.messages or {}
  return ChannelContextMerger.Merge(messages, { displayName = "Crafter" }, {
    channelMessageStore = ChannelMessageStore,
    channelMessageState = channelState,
    conversation = conversation,
    now = now,
  })
end

local function countContext(messages)
  local count = 0
  for _, message in ipairs(messages) do
    if message.kind == "channel_context" then
      count = count + 1
    end
  end
  return count
end

return function()
  -- test_shown_post_survives_channel_ttl_in_existing_conversation
  do
    local store = newStore()
    local conversation = addConversation(store, "wow::WOW::crafter", 1000)
    local channelState = ChannelMessageStore.New()
    ChannelMessageStore.Record(channelState, "Crafter-Kazzak", "LFW " .. LINK, "Trade", 1100)
    merge(channelState, conversation, 1200)

    -- Relog after the channel TTL: the channel store drops its entry.
    local restored = ChannelMessageStore.Restore(channelState, nil, 1100 + CHANNEL_TTL + 1)
    local result = merge(restored, conversation, 1100 + CHANNEL_TTL + 1)
    assert(countContext(result) == 1, "shown Trade post must survive the channel TTL, got " .. countContext(result))
    assert(result[#result].text == "LFW " .. LINK, "persisted post must keep its hyperlink intact")
  end

  -- test_persisted_post_does_not_touch_unread_or_activity
  do
    local store = newStore()
    local conversation = addConversation(store, "wow::WOW::crafter", 1000)
    local channelState = ChannelMessageStore.New()
    ChannelMessageStore.Record(channelState, "Crafter-Kazzak", "WTS", "Trade", 1100)
    merge(channelState, conversation, 1200)
    assert(conversation.unreadCount == 1, "Trade post must not add unread, got " .. tostring(conversation.unreadCount))
    assert(conversation.lastActivityAt == 1000, "Trade post must not bump activity, got " .. tostring(conversation.lastActivityAt))
  end

  -- test_live_and_persisted_copy_are_not_duplicated
  do
    local store = newStore()
    local conversation = addConversation(store, "wow::WOW::crafter", 1000)
    local channelState = ChannelMessageStore.New()
    ChannelMessageStore.Record(channelState, "Crafter-Kazzak", "WTS", "Trade", 1100)
    merge(channelState, conversation, 1200)
    local result = merge(channelState, conversation, 1201)
    assert(countContext(result) == 1, "persisted + live copy must show once, got " .. countContext(result))
    assert(countContext(conversation.messages) == 1, "repeat merges must not stack copies")
  end

  -- test_newer_post_replaces_older_persisted_post
  do
    local store = newStore()
    local conversation = addConversation(store, "wow::WOW::crafter", 1000)
    local channelState = ChannelMessageStore.New()
    ChannelMessageStore.Record(channelState, "Crafter-Kazzak", "old post", "Trade", 900)
    merge(channelState, conversation, 1200)
    ChannelMessageStore.Record(channelState, "Crafter-Kazzak", "new post", "Trade", 1100)
    merge(channelState, conversation, 1200)
    assert(countContext(conversation.messages) == 1, "only the latest post per sender is kept")
    assert(conversation.messages[1].text == "hi", "whisper stays first")
    assert(conversation.messages[2].text == "new post", "latest post kept in time order")
  end

  -- test_stored_only_for_existing_conversation
  do
    local store = newStore()
    local channelState = ChannelMessageStore.New()
    ChannelMessageStore.Record(channelState, "Crafter-Kazzak", "WTS", "Trade", 1100)
    local result = merge(channelState, nil, 1200)
    assert(countContext(result) == 1, "without a conversation the post still shows live")
    assert(next(store.conversations) == nil, "no conversation may be created from a Trade post")
  end

  -- test_group_conversation_does_not_store_channel_post
  do
    local store = newStore()
    local conversation = addConversation(store, "GUILD::Crafter", 1000)
    conversation.channel = "GUILD"
    local channelState = ChannelMessageStore.New()
    ChannelMessageStore.Record(channelState, "Crafter-Kazzak", "WTS", "Trade", 1100)
    merge(channelState, conversation, 1200)
    assert(countContext(conversation.messages) == 0, "only whisper conversations may store a Trade post")
  end

  -- test_persisted_post_expires_with_global_message_ttl
  do
    local store = newStore()
    local conversation = addConversation(store, "wow::WOW::crafter", 5000)
    local channelState = ChannelMessageStore.New()
    ChannelMessageStore.Record(channelState, "Crafter-Kazzak", "WTS", "Trade", 1000)
    merge(channelState, conversation, 1200)
    assert(countContext(conversation.messages) == 1, "precondition: post persisted")
    ConversationStore.ExpireAll(store, 1000 + MESSAGE_MAX_AGE + 1)
    assert(countContext(conversation.messages) == 0, "post must expire with the whisper history max age")
    assert(#conversation.messages == 1, "the newer whisper stays")
  end

  -- test_persisted_post_removed_with_deleted_conversation
  do
    local store = newStore()
    local conversation = addConversation(store, "wow::WOW::crafter", 1000)
    local channelState = ChannelMessageStore.New()
    ChannelMessageStore.Record(channelState, "Crafter-Kazzak", "WTS", "Trade", 1100)
    merge(channelState, conversation, 1200)
    ConversationStore.Remove(store, "wow::WOW::crafter")
    assert(store.conversations["wow::WOW::crafter"] == nil, "conversation and its stored Trade post are gone")
  end
end
