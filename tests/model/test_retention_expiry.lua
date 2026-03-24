local Retention = require("WhisperMessenger.Model.Retention")
local Store = require("WhisperMessenger.Model.ConversationStore")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")

return function()
  -- test_expire_messages_removes_old
  do
    local messages = { { sentAt = 100 }, { sentAt = 200 }, { sentAt = 300 } }
    Retention.ExpireMessages(messages, 150, 350) -- threshold = 350-150 = 200
    -- messages[1] (sentAt=100) is older than threshold 200, removed
    -- messages[2] (sentAt=200) is exactly at boundary, kept (not strictly older)
    -- messages[3] (sentAt=300) is newer, kept
    assert(#messages == 2, "expected 2 messages, got " .. #messages)
    assert(messages[1].sentAt == 200, "expected first message sentAt=200, got " .. tostring(messages[1].sentAt))
    assert(messages[2].sentAt == 300, "expected second message sentAt=300, got " .. tostring(messages[2].sentAt))
  end

  -- test_expire_messages_no_op_when_nil_max_age
  do
    local messages = { { sentAt = 1 } }
    Retention.ExpireMessages(messages, nil, 999999)
    assert(#messages == 1, "expected 1 message when maxAgeSeconds is nil, got " .. #messages)
  end

  -- test_expire_messages_removes_all_when_all_old
  do
    local messages = { { sentAt = 1 }, { sentAt = 2 } }
    Retention.ExpireMessages(messages, 10, 100)
    assert(#messages == 0, "expected 0 messages when all are old, got " .. #messages)
  end

  -- test_expire_conversations_removes_inactive
  do
    local conversations = {
      a = { lastActivityAt = 100 },
      b = { lastActivityAt = 300 },
    }
    Retention.ExpireConversations(conversations, 150, 350) -- threshold = 350-150 = 200
    assert(conversations.a == nil, "expected conversation a to be expired")
    assert(conversations.b ~= nil, "expected conversation b to be kept")
  end

  -- test_expire_conversations_keeps_pinned
  do
    local conversations = {
      a = { lastActivityAt = 1, pinned = true },
    }
    Retention.ExpireConversations(conversations, 10, 100)
    assert(conversations.a ~= nil, "expected pinned conversation a to be kept")
  end

  -- test_expire_conversations_no_op_when_nil_max_age
  do
    local conversations = {
      a = { lastActivityAt = 1 },
    }
    Retention.ExpireConversations(conversations, nil, 999)
    assert(conversations.a ~= nil, "expected conversation a to remain when maxAgeSeconds is nil")
  end

  -- test_store_expire_all_purges_old_conversations_and_messages
  do
    local now = 10000
    local state = Store.New({
      messageMaxAge = 3600,
      conversationMaxAge = 3600,
    })

    -- recent conversation: lastActivityAt = now - 100 (well within 3600s)
    state.conversations["key::recent"] = {
      messages = { { sentAt = now - 100 }, { sentAt = now - 50 } },
      lastActivityAt = now - 100,
      unreadCount = 0,
    }

    -- stale conversation: lastActivityAt = now - 7200 (older than 3600s)
    state.conversations["key::stale"] = {
      messages = { { sentAt = now - 7200 } },
      lastActivityAt = now - 7200,
      unreadCount = 0,
    }

    Store.ExpireAll(state, now)

    assert(state.conversations["key::stale"] == nil, "expected stale conversation to be removed")
    assert(state.conversations["key::recent"] ~= nil, "expected recent conversation to be kept")
    assert(
      #state.conversations["key::recent"].messages == 2,
      "expected recent conversation messages to be intact, got " .. #state.conversations["key::recent"].messages
    )
  end

  -- test_store_expire_all_removes_old_messages_from_kept_conversations
  do
    local now = 10000
    local state = Store.New({
      messageMaxAge = 3600,
      conversationMaxAge = 86400,
    })

    state.conversations["key::mixed"] = {
      messages = {
        { sentAt = now - 7200 }, -- old, should be removed
        { sentAt = now - 100 }, -- recent, should be kept
      },
      lastActivityAt = now - 100,
      unreadCount = 0,
    }

    Store.ExpireAll(state, now)

    local conv = state.conversations["key::mixed"]
    assert(conv ~= nil, "expected mixed conversation to be kept")
    assert(#conv.messages == 1, "expected 1 message after expiry, got " .. #conv.messages)
    assert(conv.messages[1].sentAt == now - 100, "expected remaining message to be the recent one")
  end

  -- test_default_config_has_24h_expiry
  do
    local runtime = RuntimeFactory.CreateRuntimeState(
      { conversations = {} },
      { activeConversationKey = nil },
      "testplayer",
      {}
    )
    assert(
      runtime.store.config.messageMaxAge == 86400,
      "expected default messageMaxAge=86400, got " .. tostring(runtime.store.config.messageMaxAge)
    )
    assert(
      runtime.store.config.conversationMaxAge == 86400,
      "expected default conversationMaxAge=86400, got " .. tostring(runtime.store.config.conversationMaxAge)
    )
  end

  -- test_conversation_max_age_follows_message_max_age_from_settings
  do
    local runtime = RuntimeFactory.CreateRuntimeState(
      { conversations = {}, settings = { messageMaxAge = 7200 } },
      { activeConversationKey = nil },
      "testplayer",
      {}
    )
    assert(
      runtime.store.config.messageMaxAge == 7200,
      "expected messageMaxAge=7200 from settings, got " .. tostring(runtime.store.config.messageMaxAge)
    )
    assert(
      runtime.store.config.conversationMaxAge == 7200,
      "expected conversationMaxAge to match messageMaxAge=7200, got "
        .. tostring(runtime.store.config.conversationMaxAge)
    )
  end

  -- test_expire_all_removes_stale_contacts_within_retention_period
  do
    local now = 10000
    local state = Store.New({
      messageMaxAge = 3600,
      conversationMaxAge = 3600,
    })

    state.conversations["key::stale-contact"] = {
      messages = {},
      lastActivityAt = now - 5000,
      unreadCount = 0,
    }
    state.conversations["key::recent-contact"] = {
      messages = { { sentAt = now - 100 } },
      lastActivityAt = now - 100,
      unreadCount = 0,
    }

    Store.ExpireAll(state, now)

    assert(
      state.conversations["key::stale-contact"] == nil,
      "expected stale contact (last activity > retention) to be removed"
    )
    assert(state.conversations["key::recent-contact"] ~= nil, "expected recent contact to be kept")
  end
end
