local Store = require("WhisperMessenger.Model.ConversationStore")

local function incoming(id)
  return { id = id, direction = "in", kind = "user", text = "hi", sentAt = 1 }
end

return function()
  -- test_mark_all_read_clears_unread_on_every_conversation
  local state = Store.New({ maxMessagesPerConversation = 10 })
  Store.AppendIncoming(state, "me::WOW::arthas-area52", incoming("1"), false)
  Store.AppendIncoming(state, "me::BN::jaina#1234", incoming("2"), false)
  Store.AppendIncoming(state, "channel::GUILD", incoming("3"), false)
  state.conversations["channel::GUILD"].unreadActivityCount = 2
  state.conversations["channel::GUILD"].hasUnreadMention = true

  Store.MarkAllRead(state)

  for key, conversation in pairs(state.conversations) do
    assert(conversation.unreadCount == 0, key .. " unread cleared, got " .. tostring(conversation.unreadCount))
    assert(conversation.unreadActivityCount == 0, key .. " activity unread cleared")
    assert(conversation.hasUnreadMention == nil, key .. " mention cleared")
  end

  -- test_mark_all_read_on_empty_store_is_noop
  local empty = Store.New({ maxMessagesPerConversation = 10 })
  Store.MarkAllRead(empty)
  assert(next(empty.conversations) == nil, "no conversations created")
end
