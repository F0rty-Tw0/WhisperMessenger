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

  -- test_battletag_persisted_on_append_incoming
  do
    local s = Store.New({})
    Store.AppendIncoming(s, "me::BN::16", {
      id = "bt1",
      direction = "in",
      kind = "user",
      text = "hey",
      sentAt = 10,
      battleTag = "Friend#1234",
    }, false)
    local conv = s.conversations["me::BN::16"]
    assert(conv ~= nil, "conversation should exist")
    assert(
      conv.battleTag == "Friend#1234",
      "battleTag should be persisted on conversation, got: " .. tostring(conv.battleTag)
    )
  end

  -- test_battletag_not_overwritten_by_nil
  do
    local s = Store.New({})
    Store.AppendIncoming(s, "me::BN::17", {
      id = "bt2",
      direction = "in",
      kind = "user",
      text = "first",
      sentAt = 11,
      battleTag = "Keep#5678",
    }, false)
    Store.AppendIncoming(s, "me::BN::17", {
      id = "bt3",
      direction = "in",
      kind = "user",
      text = "second",
      sentAt = 12,
      battleTag = nil,
    }, false)
    local conv = s.conversations["me::BN::17"]
    assert(
      conv.battleTag == "Keep#5678",
      "battleTag should not be overwritten by nil, got: " .. tostring(conv.battleTag)
    )
  end
end
