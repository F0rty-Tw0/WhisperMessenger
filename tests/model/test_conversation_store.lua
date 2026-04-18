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

  -- test_last_incoming_preview_tracks_latest_incoming_only
  do
    local s = Store.New({})
    Store.AppendIncoming(s, "me::WOW::jaina-proudmoore", {
      id = "in-1",
      direction = "in",
      kind = "user",
      text = "Need assistance?",
      sentAt = 10,
      playerName = "Jaina-Proudmoore",
    }, false)
    Store.AppendOutgoing(s, "me::WOW::jaina-proudmoore", {
      id = "out-1",
      direction = "out",
      kind = "user",
      text = "On my way.",
      sentAt = 11,
      playerName = "Me",
    })
    Store.AppendIncoming(s, "me::WOW::jaina-proudmoore", {
      id = "in-2",
      direction = "in",
      kind = "user",
      text = "Meet by the summoning stone.",
      sentAt = 12,
      playerName = "Jaina-Proudmoore",
    }, false)
    local conv = s.conversations["me::WOW::jaina-proudmoore"]
    assert(conv.lastPreview == "Meet by the summoning stone.", "lastPreview should still reflect latest activity")
    assert(
      conv.lastIncomingPreview == "Meet by the summoning stone.",
      "lastIncomingPreview should track the newest incoming user message"
    )
    assert(conv.lastIncomingSender == "Jaina-Proudmoore", "lastIncomingSender should track the incoming sender name")
    assert(conv.lastIncomingAt == 12, "lastIncomingAt should track the incoming timestamp")
  end

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

  -- test_pin_marks_conversation_pinned
  do
    local s = Store.New({})
    Store.AppendIncoming(s, "me::WOW::alice", {
      id = "p1",
      direction = "in",
      kind = "user",
      text = "hey",
      sentAt = 1,
    }, false)

    assert(Store.IsPinned(s, "me::WOW::alice") == false, "should not be pinned by default")

    Store.Pin(s, "me::WOW::alice")
    assert(Store.IsPinned(s, "me::WOW::alice") == true, "should be pinned after Pin")
  end

  -- test_unpin_removes_pinned_flag
  do
    local s = Store.New({})
    Store.AppendIncoming(s, "me::WOW::bob", {
      id = "u1",
      direction = "in",
      kind = "user",
      text = "hi",
      sentAt = 1,
    }, false)

    Store.Pin(s, "me::WOW::bob")
    assert(Store.IsPinned(s, "me::WOW::bob") == true, "precondition: pinned")

    Store.Unpin(s, "me::WOW::bob")
    assert(Store.IsPinned(s, "me::WOW::bob") == false, "should not be pinned after Unpin")
  end

  -- test_pin_nonexistent_conversation_is_noop
  do
    local s = Store.New({})
    Store.Pin(s, "me::WOW::ghost")
    assert(Store.IsPinned(s, "me::WOW::ghost") == false, "pinning nonexistent key should be noop")
  end

  -- test_remove_deletes_conversation
  do
    local s = Store.New({})
    Store.AppendIncoming(s, "me::WOW::carol", {
      id = "r1",
      direction = "in",
      kind = "user",
      text = "bye",
      sentAt = 1,
    }, false)
    assert(s.conversations["me::WOW::carol"] ~= nil, "precondition: conversation exists")

    Store.Remove(s, "me::WOW::carol")
    assert(s.conversations["me::WOW::carol"] == nil, "conversation should be removed")
  end

  -- test_remove_nonexistent_conversation_is_noop
  do
    local s = Store.New({})
    Store.Remove(s, "me::WOW::nobody")
    -- should not error
  end

  -- test_set_sort_order
  do
    local s = Store.New({})
    Store.AppendIncoming(s, "me::WOW::zara", {
      id = "so1",
      direction = "in",
      kind = "user",
      text = "hey",
      sentAt = 1,
    }, false)

    assert(
      s.conversations["me::WOW::zara"].sortOrder == nil or s.conversations["me::WOW::zara"].sortOrder == 0,
      "default sortOrder should be 0 or nil"
    )

    Store.SetSortOrder(s, "me::WOW::zara", 5)
    assert(s.conversations["me::WOW::zara"].sortOrder == 5, "sortOrder should be 5 after SetSortOrder")
  end

  -- test_swap_order_between_two_conversations
  do
    local s = Store.New({})
    Store.AppendIncoming(s, "me::WOW::one", {
      id = "sw1",
      direction = "in",
      kind = "user",
      text = "a",
      sentAt = 1,
    }, false)
    Store.AppendIncoming(s, "me::WOW::two", {
      id = "sw2",
      direction = "in",
      kind = "user",
      text = "b",
      sentAt = 2,
    }, false)

    Store.SetSortOrder(s, "me::WOW::one", 1)
    Store.SetSortOrder(s, "me::WOW::two", 2)

    Store.SwapOrder(s, "me::WOW::one", "me::WOW::two")
    assert(s.conversations["me::WOW::one"].sortOrder == 2, "one should have order 2 after swap")
    assert(s.conversations["me::WOW::two"].sortOrder == 1, "two should have order 1 after swap")
  end

  -- test_set_sort_order_nonexistent_is_noop
  do
    local s = Store.New({})
    Store.SetSortOrder(s, "me::WOW::ghost", 3)
    -- should not error
  end
end
