local Retention = require("WhisperMessenger.Model.Retention")
local Store = require("WhisperMessenger.Model.ConversationStore")
local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local MessageReactions = require("WhisperMessenger.Model.MessageReactions")

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

  -- test_missing_timestamp_is_not_expired
  -- A record with no timestamp yet (freshly ensured conversation, message
  -- missing sentAt) must be kept conservatively, not treated as infinitely old.
  do
    assert(Retention.IsExpired(nil, 100, 99999) == false, "nil timestamp must not count as expired")
    assert(Retention.IsExpired(0, 100, 99999) == false, "zero timestamp must not count as expired")

    local conversations = {
      fresh = { lastActivityAt = 0 },
      old = { lastActivityAt = 100 },
    }
    Retention.ExpireConversations(conversations, 150, 99999)
    assert(conversations.fresh ~= nil, "freshly-created conversation (lastActivityAt=0) must be kept")
    assert(conversations.old == nil, "genuinely old conversation is still expired")
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

  -- test_store_expire_all_trims_loaded_recent_history_to_message_cap
  do
    local now = 10000
    local state = Store.New({
      maxMessagesPerConversation = 2,
      messageMaxAge = 86400,
      conversationMaxAge = 86400,
    })

    state.conversations["key::loaded-recent"] = {
      pinned = false,
      messages = {
        { id = "oldest", sentAt = now - 400 },
        { id = "older", sentAt = now - 300 },
        { id = "newer", sentAt = now - 200 },
        { id = "newest", sentAt = now - 100 },
      },
      lastActivityAt = now - 100,
      unreadCount = 0,
    }

    Store.ExpireAll(state, now)

    local conv = state.conversations["key::loaded-recent"]
    assert(conv ~= nil, "expected loaded recent conversation to be kept")
    assert(#conv.messages == 2, "expected startup expiry to enforce message cap, got " .. #conv.messages)
    assert(conv.messages[1].id == "newer", "expected startup expiry to retain the newer message")
    assert(conv.messages[2].id == "newest", "expected startup expiry to retain the newest message")
  end

  -- test_pinned_conversations_keep_old_messages_but_still_honor_count_cap
  do
    local state = Store.New({
      maxMessagesPerConversation = 2,
      messageMaxAge = 3600,
      conversationMaxAge = 86400,
    })
    local key = "key::pinned-cap"
    Store.AppendIncoming(state, key, {
      id = "1",
      direction = "in",
      kind = "user",
      text = "old",
      sentAt = 1,
    }, false)
    Store.Pin(state, key)
    Store.AppendIncoming(state, key, {
      id = "2",
      direction = "in",
      kind = "user",
      text = "middle",
      sentAt = 2,
    }, false)
    Store.AppendIncoming(state, key, {
      id = "3",
      direction = "in",
      kind = "user",
      text = "new",
      sentAt = 3,
    }, false)

    local conv = state.conversations[key]
    assert(conv ~= nil, "expected pinned conversation to exist")
    assert(conv.pinned == true, "expected conversation to remain pinned")
    assert(#conv.messages == 2, "expected pinned conversation to stay capped at 2 messages, got " .. #conv.messages)
    assert(conv.messages[1].id == "2", "expected oldest capped message to be id 2, got " .. tostring(conv.messages[1].id))
    assert(conv.messages[2].id == "3", "expected newest capped message to be id 3, got " .. tostring(conv.messages[2].id))
  end

  -- test_store_expire_all_keeps_old_messages_for_pinned_conversations
  do
    local now = 10000
    local state = Store.New({
      maxMessagesPerConversation = 5,
      messageMaxAge = 3600,
      conversationMaxAge = 3600,
    })

    state.conversations["key::pinned-history"] = {
      pinned = true,
      messages = {
        { id = "old", sentAt = now - 7200 },
        { id = "recent", sentAt = now - 100 },
      },
      lastActivityAt = now - 100,
      unreadCount = 0,
    }

    Store.ExpireAll(state, now)

    local conv = state.conversations["key::pinned-history"]
    assert(conv ~= nil, "expected pinned conversation to remain after ExpireAll")
    assert(#conv.messages == 2, "expected pinned conversation messages to skip age expiry, got " .. #conv.messages)
    assert(conv.messages[1].id == "old", "expected oldest pinned message to remain after ExpireAll")
    assert(conv.messages[2].id == "recent", "expected recent pinned message to remain after ExpireAll")
  end

  -- test_unpin_reapplies_message_retention_immediately
  do
    local now = 10000
    local savedTime = _G.time
    rawset(_G, "time", function()
      return now
    end)

    local state = Store.New({
      maxMessagesPerConversation = 5,
      messageMaxAge = 3600,
      conversationMaxAge = 86400,
    })

    state.conversations["key::unpinned-trim"] = {
      pinned = true,
      messages = {
        { id = "old", sentAt = now - 7200 },
        { id = "recent", sentAt = now - 120 },
      },
      lastActivityAt = now - 120,
      unreadCount = 0,
    }

    Store.Unpin(state, "key::unpinned-trim")

    rawset(_G, "time", savedTime)

    local conv = state.conversations["key::unpinned-trim"]
    assert(conv ~= nil, "expected recently active conversation to survive unpin")
    assert(conv.pinned == false, "expected conversation to be unpinned")
    assert(#conv.messages == 1, "expected old pinned history to be trimmed after unpin, got " .. #conv.messages)
    assert(conv.messages[1].id == "recent", "expected recent message to remain after unpin")
  end

  -- test_unpin_removes_stale_conversation_immediately
  do
    local now = 10000
    local savedTime = _G.time
    rawset(_G, "time", function()
      return now
    end)

    local state = Store.New({
      maxMessagesPerConversation = 5,
      messageMaxAge = 3600,
      conversationMaxAge = 3600,
    })

    state.conversations["key::unpinned-stale"] = {
      pinned = true,
      messages = { { id = "old", sentAt = now - 7200 } },
      lastActivityAt = now - 7200,
      unreadCount = 0,
    }

    Store.Unpin(state, "key::unpinned-stale")

    rawset(_G, "time", savedTime)

    assert(state.conversations["key::unpinned-stale"] == nil, "expected stale pinned conversation to be removed immediately after unpin")
  end

  -- test_apply_retention_trims_messages_expires_unpinned_and_reports_removals
  do
    local now = 10000
    local state = Store.New({
      maxMessagesPerConversation = 2,
      maxConversations = 10,
      messageMaxAge = 3600,
      conversationMaxAge = 3600,
    })
    state.conversations["key::recent"] = {
      messages = {
        { id = "old", sentAt = now - 7200 },
        { id = "middle", sentAt = now - 200 },
        { id = "new", sentAt = now - 100 },
      },
      lastActivityAt = now - 100,
    }
    state.conversations["key::pinned"] = {
      pinned = true,
      messages = {
        { id = "old", sentAt = now - 7200 },
        { id = "middle", sentAt = now - 200 },
        { id = "new", sentAt = now - 100 },
      },
      lastActivityAt = now - 7200,
    }
    state.conversations["key::stale"] = {
      messages = {},
      lastActivityAt = now - 7200,
    }
    state.conversations["key::oldest"] = {
      messages = {},
      lastActivityAt = now - 300,
    }
    state.conversations["key::active"] = {
      messages = {},
      lastActivityAt = now - 400,
    }

    local removed = Store.ApplyRetention(state, now)

    assert(state.conversations["key::stale"] == nil, "expired unpinned conversation must be removed immediately")
    assert(removed["key::stale"] == true, "removed keys must report expired conversations")
    assert(#state.conversations["key::recent"].messages == 2, "recent conversation must honor lowered message cap")
    assert(state.conversations["key::recent"].messages[1].id == "middle", "message cap must retain recent messages")
    assert(state.conversations["key::pinned"] ~= nil, "pinned conversation must ignore age expiry")
    assert(#state.conversations["key::pinned"].messages == 2, "pinned conversation must still honor message cap")
    assert(state.conversations["key::pinned"].messages[1].id == "middle", "pinned cap must retain recent messages")
    state.config.maxConversations = 2
    local capRemoved = Store.ApplyRetention(state, now, "key::active")

    assert(state.conversations["key::oldest"] == nil, "lower contact cap must remove oldest eligible conversation")
    assert(state.conversations["key::recent"] == nil, "contact cap must use activity then key deterministically")
    assert(state.conversations["key::active"] ~= nil, "protected active conversation must survive contact cap")
    assert(capRemoved["key::oldest"] == true and capRemoved["key::recent"] == true, "removed keys must report cap evictions")
  end

  -- test_default_config_has_24h_expiry
  do
    local runtime = RuntimeFactory.CreateRuntimeState({ conversations = {} }, { activeConversationKey = nil }, "testplayer", {})
    assert(runtime.store.config.messageMaxAge == 86400, "expected default messageMaxAge=86400, got " .. tostring(runtime.store.config.messageMaxAge))
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
      "expected conversationMaxAge to match messageMaxAge=7200, got " .. tostring(runtime.store.config.conversationMaxAge)
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

    assert(state.conversations["key::stale-contact"] == nil, "expected stale contact (last activity > retention) to be removed")
    assert(state.conversations["key::recent-contact"] ~= nil, "expected recent contact to be kept")
  end
  -- test_append_reapplies_unpinned_age_retention_during_long_sessions
  do
    local state = Store.New({
      maxMessagesPerConversation = 10,
      maxConversations = 10,
      messageMaxAge = 100,
      conversationMaxAge = 1000,
    })
    state.conversations["key::active"] = {
      messages = {
        { id = "expired", sentAt = 800 },
        { id = "recent", sentAt = 950 },
      },
      lastActivityAt = 950,
      unreadCount = 0,
    }

    Store.AppendIncoming(state, "key::active", {
      id = "new",
      direction = "in",
      kind = "user",
      text = "new",
      sentAt = 1000,
    }, false)

    local messages = state.conversations["key::active"].messages
    assert(#messages == 2, "long-session append must expire old unpinned messages")
    assert(messages[1].id == "recent" and messages[2].id == "new", "long-session append must retain only in-age messages")
  end

  -- test_append_reapplies_conversation_age_retention_during_long_sessions
  do
    local state = Store.New({
      maxMessagesPerConversation = 10,
      maxConversations = 10,
      messageMaxAge = 100,
      conversationMaxAge = 100,
    })
    state.conversations["key::stale"] = {
      messages = { { id = "old", sentAt = 1 } },
      lastActivityAt = 1,
      unreadCount = 0,
    }

    Store.AppendIncoming(state, "key::active", {
      id = "new",
      direction = "in",
      kind = "user",
      text = "new",
      sentAt = 1000,
    }, false)

    assert(state.conversations["key::stale"] == nil, "long-session append must remove expired unpinned conversations")
    assert(state.conversations["key::active"] ~= nil, "long-session retention must protect the conversation receiving the message")
  end

  -- test_expired_chronological_insert_has_no_side_effects_or_detached_return
  do
    local now = 1000
    local state = Store.New({
      maxMessagesPerConversation = 10,
      maxConversations = 10,
      messageMaxAge = 100,
      conversationMaxAge = 100,
    }, function()
      return now
    end)
    local activeStatus = { kind = "afk", sentAt = 700 }
    local conversation = {
      displayName = "Original",
      guid = "Player-original",
      messages = {},
      lastPreview = "original preview",
      lastActivityAt = 800,
      unreadCount = 2,
      activeStatus = activeStatus,
    }
    state.conversations["key::expired"] = conversation

    local returned = Store.InsertIncomingChronological(state, "key::expired", {
      id = "expired",
      direction = "in",
      kind = "user",
      text = "expired delayed message",
      playerName = "Replacement",
      guid = "Player-replacement",
      sentAt = 800,
      lineID = 1,
    }, false)

    assert(state.conversations["key::expired"] == nil, "expired conversation must be removed with its discarded insert")
    assert(#conversation.messages == 0, "expired insert must not remain in detached transcript")
    assert(conversation.unreadCount == 2, "expired insert must not mutate unread state")
    assert(
      conversation.displayName == "Original" and conversation.guid == "Player-original" and conversation.lastPreview == "original preview",
      "expired insert must not mutate conversation metadata"
    )
    assert(conversation.activeStatus == activeStatus, "expired insert must not clear active status")
    assert(returned == nil, "expired insert must return actual stored conversation state")
  end

  -- test_count_trimmed_chronological_insert_has_no_side_effects
  do
    local now = 1000
    local state = Store.New({
      maxMessagesPerConversation = 1,
      maxConversations = 10,
      messageMaxAge = 1000,
      conversationMaxAge = 1000,
    }, function()
      return now
    end)
    local key = "key::count-trimmed"
    local activeStatus = { kind = "afk", sentAt = 800 }
    local conversation = {
      displayName = "Original",
      guid = "Player-original",
      messages = { { id = "recent", sentAt = 950, lineID = 2 } },
      lastPreview = "recent",
      lastActivityAt = 950,
      unreadCount = 2,
      activeStatus = activeStatus,
    }
    state.conversations[key] = conversation

    local returned = Store.InsertIncomingChronological(state, key, {
      id = "trimmed",
      direction = "in",
      kind = "user",
      text = "old delayed message",
      playerName = "Replacement",
      guid = "Player-replacement",
      sentAt = 900,
      lineID = 1,
    }, false)

    assert(#conversation.messages == 1 and conversation.messages[1].id == "recent", "count-trimmed insert must not change transcript")
    assert(conversation.unreadCount == 2, "count-trimmed insert must not mutate unread state")
    assert(
      conversation.displayName == "Original" and conversation.guid == "Player-original" and conversation.lastPreview == "recent",
      "count-trimmed insert must not mutate conversation metadata"
    )
    assert(conversation.activeStatus == activeStatus, "count-trimmed insert must not clear active status")
    assert(returned == state.conversations[key], "count-trimmed insert must return stored conversation")
  end

  -- test_message_valid_chronological_insert_cannot_revive_expired_conversation
  do
    local now = 1000
    local state = Store.New({
      maxMessagesPerConversation = 10,
      maxConversations = 10,
      messageMaxAge = 500,
      conversationMaxAge = 100,
    }, function()
      return now
    end)
    local key = "key::conversation-expired"
    local activeStatus = { kind = "afk", sentAt = 700 }
    local conversation = {
      displayName = "Original",
      guid = "Player-original",
      messages = {},
      lastPreview = "original preview",
      lastActivityAt = 800,
      unreadCount = 2,
      activeStatus = activeStatus,
    }
    local removedKey
    local removedConversation
    state.conversations[key] = conversation
    state.onConversationRemoved = function(nextKey, nextConversation)
      removedKey = nextKey
      removedConversation = nextConversation
    end

    local returned = Store.InsertIncomingChronological(state, key, {
      id = "message-valid",
      direction = "in",
      kind = "user",
      text = "still too old for conversation",
      playerName = "Replacement",
      guid = "Player-replacement",
      sentAt = 850,
      lineID = 1,
    }, false)

    assert(state.conversations[key] == nil and #conversation.messages == 0, "expired conversation must retain no transcript")
    assert(conversation.unreadCount == 2, "conversation-expired insert must not mutate unread state")
    assert(
      conversation.displayName == "Original" and conversation.guid == "Player-original" and conversation.lastPreview == "original preview",
      "conversation-expired insert must not mutate conversation metadata"
    )
    assert(conversation.activeStatus == activeStatus, "conversation-expired insert must not clear active status")
    assert(removedKey == key and removedConversation == conversation, "conversation expiry must use central removal lifecycle")
    assert(returned == nil, "conversation-expired insert must return nil")
  end

  -- test_append_preserves_pinned_message_age_exemption
  do
    local state = Store.New({
      maxMessagesPerConversation = 2,
      maxConversations = 10,
      messageMaxAge = 100,
      conversationMaxAge = 1000,
    })
    state.conversations["key::pinned"] = {
      pinned = true,
      messages = {
        { id = "expired", sentAt = 1 },
      },
      lastActivityAt = 1,
      unreadCount = 0,
    }

    Store.AppendIncoming(state, "key::pinned", {
      id = "new",
      direction = "in",
      kind = "user",
      text = "new",
      sentAt = 1000,
    }, false)

    local messages = state.conversations["key::pinned"].messages
    assert(#messages == 2, "pinned append must keep old messages while honoring count cap")
    assert(messages[1].id == "expired" and messages[2].id == "new", "pinned append must preserve old history exactly")
  end

  -- test_runtime_cache_cleanup_preserves_active_pending_sends
  do
    local now = 1000
    local key = "wow::WOW::cached-realm"
    local guid = "Player-cached"
    local runtime = RuntimeFactory.CreateRuntimeState(
      {
        conversations = {
          [key] = {
            conversationKey = key,
            guid = guid,
            messages = {},
            lastActivityAt = now,
          },
        },
      },
      { activeConversationKey = nil },
      "wow",
      {
        now = function()
          return now
        end,
      }
    )
    runtime.pendingOutgoing[key] = { { createdAt = now } }
    runtime.pendingGroupOutgoing = { [key] = { { createdAt = now } } }
    runtime.sendStatusByConversation[key] = { status = "sent" }
    runtime.availabilityByGUID[guid] = { status = "CanWhisper" }
    runtime.availabilityRequestedAt = { [guid] = now }
    MessageReactions.RecordIdentity(runtime, "sender", key, {
      type = "identity",
      wireId = "wire",
      sourceFingerprint = "fingerprint",
    }, now)

    Store.Remove(runtime.store, key)

    assert(runtime.pendingOutgoing[key] ~= nil, "conversation removal must preserve active whisper sends until inform or expiry")
    assert(runtime.pendingGroupOutgoing[key] ~= nil, "conversation removal must preserve active group sends until echo or expiry")
    assert(runtime.sendStatusByConversation[key] == nil, "conversation removal must clear its send status")
    assert(runtime.availabilityByGUID[guid] == nil, "last GUID owner removal must clear resolved availability")
    assert(runtime.availabilityRequestedAt[guid] == nil, "last GUID owner removal must clear resolver request state")
    assert(runtime.messageReactionRuntime.identityMetadata.sender == nil, "conversation removal must clear reaction correlation state")
  end
  -- test_guid_replacement_clears_orphaned_resolver_cache
  do
    local now = 1000
    local key = "wow::WOW::renamed-realm"
    local oldGuid = "Player-old"
    local runtime = RuntimeFactory.CreateRuntimeState(
      {
        conversations = {
          [key] = {
            conversationKey = key,
            guid = oldGuid,
            messages = {},
            lastActivityAt = now,
            unreadCount = 0,
          },
        },
      },
      { activeConversationKey = nil },
      "wow",
      {
        now = function()
          return now
        end,
      }
    )
    runtime.availabilityByGUID[oldGuid] = { status = "CanWhisper" }
    runtime.availabilityRequestedAt = { [oldGuid] = now }

    Store.AppendIncoming(runtime.store, key, {
      direction = "in",
      kind = "user",
      text = "new identity",
      sentAt = now,
      guid = "Player-new",
    }, false)

    assert(runtime.availabilityByGUID[oldGuid] == nil, "GUID replacement must clear orphaned availability")
    assert(runtime.availabilityRequestedAt[oldGuid] == nil, "GUID replacement must clear orphaned resolver requests")
  end
end
