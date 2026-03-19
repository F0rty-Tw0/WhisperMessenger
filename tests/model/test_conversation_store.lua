local Store = require("WhisperMessenger.Model.ConversationStore")

return function()
  local state = Store.New({ maxMessagesPerConversation = 3 })

  Store.AppendIncoming(state, "me::WOW::arthas-area52", {
    id = "1",
    direction = "in",
    kind = "user",
    text = "hi",
    sentAt = 1,
  }, false)

  assert(state.conversations["me::WOW::arthas-area52"].unreadCount == 1)

  Store.AppendOutgoing(state, "me::WOW::arthas-area52", {
    id = "2",
    direction = "out",
    kind = "user",
    text = "hello",
    sentAt = 2,
  })

  Store.AppendIncoming(state, "me::WOW::arthas-area52", {
    id = "echo-2",
    direction = "out",
    kind = "user",
    text = "hello",
    sentAt = 2,
  }, false)

  assert(state.conversations["me::WOW::arthas-area52"].unreadCount == 1)

  Store.AppendIncoming(state, "me::WOW::arthas-area52", {
    id = "3",
    direction = "in",
    kind = "user",
    text = "still there?",
    sentAt = 3,
  }, true)

  Store.AppendIncoming(state, "me::WOW::arthas-area52", {
    id = "4",
    direction = "in",
    kind = "user",
    text = "ping",
    sentAt = 4,
  }, false)

  local conversation = state.conversations["me::WOW::arthas-area52"]
  assert(conversation.unreadCount == 2)
  assert(#conversation.messages == 3)
  assert(conversation.messages[1].id == "echo-2")
  assert(conversation.lastPreview == "ping")
  assert(conversation.lastActivityAt == 4)

  Store.MarkRead(state, "me::WOW::arthas-area52")
  assert(conversation.unreadCount == 0)
end
