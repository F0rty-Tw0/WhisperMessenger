local Retention = require("WhisperMessenger.Model.Retention")
local Store = require("WhisperMessenger.Model.ConversationStore")

local NOW = 100000
local OLD = NOW - 90000

local function idleConversation(extra)
  local conversation = { messages = { { sentAt = OLD, direction = "in", kind = "user" } }, lastActivityAt = OLD, unreadCount = 0 }
  for field, value in pairs(extra or {}) do
    conversation[field] = value
  end
  return conversation
end

return function()
  -- test_expire_all_expires_conversations_with_player_prefs
  do
    local state = Store.New({ conversationMaxAge = 86400, messageMaxAge = 86400 })
    state.conversations["k::muted"] = idleConversation({ muted = true })
    state.conversations["k::nick"] = idleConversation({ nickname = "Bestie" })
    state.conversations["k::note"] = idleConversation({ note = "raid lead" })
    state.conversations["k::notify"] = idleConversation({ notifyOnline = true })
    state.conversations["k::draft"] = idleConversation({ draft = "half typed" })

    Store.ExpireAll(state, NOW)

    for _, key in ipairs({ "k::muted", "k::nick", "k::note", "k::notify", "k::draft" }) do
      assert(state.conversations[key] == nil, key .. " must follow the retention timeout")
    end
  end

  -- test_expire_all_keeps_pinned_conversation
  do
    local state = Store.New({ conversationMaxAge = 86400, messageMaxAge = 86400 })
    state.conversations["k::pinned"] = idleConversation({ pinned = true })

    Store.ExpireAll(state, NOW)

    assert(state.conversations["k::pinned"] ~= nil, "pinned conversation survives retention")
  end

  -- test_expire_all_keeps_conversation_with_queued_message
  do
    local state = Store.New({ conversationMaxAge = 86400, messageMaxAge = 86400 })
    local conversation = idleConversation()
    conversation.messages[2] = { sentAt = OLD, direction = "out", kind = "user", delivery = "queued", text = "gg" }
    state.conversations["k::queued"] = conversation

    Store.ExpireAll(state, NOW)

    local kept = state.conversations["k::queued"]
    assert(kept ~= nil, "conversation holding a queued message must survive")
    assert(#kept.messages == 1 and kept.messages[1].delivery == "queued", "queued message must not expire")
  end

  -- test_append_retention_expires_muted_conversation
  do
    local state = Store.New({ conversationMaxAge = 86400, messageMaxAge = 86400 }, function()
      return NOW
    end)
    state.conversations["k::muted"] = idleConversation({ muted = true })

    Store.AppendIncoming(state, "k::new", { sentAt = NOW, direction = "in", kind = "user", text = "hi" }, false)

    assert(state.conversations["k::muted"] == nil, "muted conversation is removed on append")
  end

  -- test_eviction_skips_pinned_conversations
  do
    local state = Store.New({ maxConversations = 2 })
    state.conversations["k::a_pinned"] = { messages = {}, lastActivityAt = 10, unreadCount = 0, pinned = true }
    state.conversations["k::b_plain"] = { messages = {}, lastActivityAt = 20, unreadCount = 0 }

    Store.EnsureConversation(state, "k::c_new")

    assert(state.conversations["k::a_pinned"] ~= nil, "oldest pinned conversation is not evicted")
    assert(state.conversations["k::b_plain"] == nil, "oldest plain conversation is evicted instead")
  end

  -- test_trim_messages_never_drops_queued
  do
    local messages = {
      { sentAt = 1, delivery = "queued" },
      { sentAt = 2 },
      { sentAt = 3 },
      { sentAt = 4 },
    }
    Retention.TrimMessages(messages, 2)
    assert(#messages == 2, "trim still caps the count, got " .. #messages)
    assert(messages[1].delivery == "queued", "queued message is kept")
    assert(messages[2].sentAt == 4, "newest normal message is kept")
  end

  -- test_expire_messages_never_drops_queued
  do
    local messages = { { sentAt = 1, delivery = "queued" }, { sentAt = 2 } }
    Retention.ExpireMessages(messages, 10, 1000)
    assert(#messages == 1 and messages[1].delivery == "queued", "queued message survives message expiry")
  end
end
