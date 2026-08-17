local PrefixMigration = require("WhisperMessenger.Persistence.SavedState.PrefixMigration")

return function()
  -- test_collision_merge_preserves_pinned_order_cap_key_references_and_idempotence
  do
    local oldKey = "alice-realm::BN::foo#1234"
    local canonicalKey = "bnet::BN::foo#1234"
    local conversations = {
      [oldKey] = {
        pinned = true,
        sortOrder = 7,
        unreadCount = 2,
        lastActivityAt = 100,
        lastPreview = "old preview",
        lastIncomingAt = 100,
        lastIncomingSender = "Alice",
        lastIncomingPreview = "old preview",
        activeStatus = { text = "Away", eventName = "CHAT_MSG_AFK" },
        messages = {
          { id = "shared", kind = "user", direction = "in", sentAt = 50, text = "shared" },
          { id = "old", kind = "user", direction = "in", sentAt = 150, text = "old" },
        },
      },
      [canonicalKey] = {
        pinned = false,
        sortOrder = 0,
        unreadCount = 2,
        lastActivityAt = 200,
        lastPreview = "latest",
        lastIncomingAt = 200,
        lastIncomingSender = "Canonical",
        lastIncomingPreview = "latest",
        activeStatus = { text = "Busy", eventName = "CHAT_MSG_DND" },
        messages = {
          { id = "shared", kind = "user", direction = "in", sentAt = 50, text = "shared" },
          { id = "canonical", kind = "user", direction = "in", sentAt = 100, text = "canonical" },
          { id = "latest", kind = "user", direction = "in", sentAt = 200, text = "latest" },
        },
      },
    }
    local characterState = { activeConversationKey = oldKey }

    local mappings = PrefixMigration.MigratePrefix(conversations, "::BN::", "bnet", characterState, 3)

    local merged = conversations[canonicalKey]
    assert(merged ~= nil, "merged conversation should exist under the canonical key")
    assert(conversations[oldKey] == nil, "legacy key should be removed")
    assert(mappings[oldKey] == canonicalKey, "migration should return the old-to-new key mapping")
    assert(characterState.activeConversationKey == canonicalKey, "active selection should follow the canonical key")
    assert(merged.pinned == true, "pinned legacy collision loser must stay pinned")
    assert(merged.sortOrder == 7, "pinned collision loser keeps its deliberate order")
    assert(merged.conversationKey == canonicalKey, "embedded key should match the canonical table key")
    assert(#merged.messages == 3, "deduplicated merged history must respect the configured cap")
    assert(
      merged.messages[1].id == "canonical" and merged.messages[2].id == "old" and merged.messages[3].id == "latest",
      "stable chronological merge should retain the newest capped history"
    )
    assert(merged.unreadCount == 3, "unread count must not exceed the retained unique incoming messages")
    assert(merged.lastActivityAt == 200 and merged.lastPreview == "latest", "latest activity metadata should stay coherent")
    assert(merged.lastIncomingAt == 200 and merged.lastIncomingSender == "Canonical", "latest incoming metadata should stay coherent")
    assert(merged.activeStatus.text == "Busy", "latest valid active status should survive")

    local secondMappings = PrefixMigration.MigratePrefix(conversations, "::BN::", "bnet", characterState, 3)
    assert(next(secondMappings) == nil, "second migration should be a no-op")
    assert(conversations[canonicalKey] == merged and #merged.messages == 3, "second migration must not change the merge result")
  end

  -- test_collision_merge_keeps_newest_activity_and_newest_incoming_metadata_separately
  do
    local oldKey = "alice-realm::BN::metadata#1234"
    local canonicalKey = "bnet::BN::metadata#1234"
    local conversations = {
      [oldKey] = {
        lastActivityAt = 200,
        lastPreview = "new outgoing",
        lastIncomingAt = 50,
        lastIncomingSender = "Old",
        lastIncomingPreview = "old incoming",
        messages = { { id = "old", kind = "user", direction = "out", sentAt = 200, text = "new outgoing" } },
      },
      [canonicalKey] = {
        lastActivityAt = 150,
        lastPreview = "new incoming",
        lastIncomingAt = 150,
        lastIncomingSender = "Canonical",
        lastIncomingPreview = "new incoming",
        messages = { { id = "canonical", kind = "user", direction = "in", sentAt = 150, text = "new incoming" } },
      },
    }

    PrefixMigration.MigratePrefix(conversations, "::BN::", "bnet", {}, 10)

    local merged = conversations[canonicalKey]
    assert(merged.lastActivityAt == 200 and merged.lastPreview == "new outgoing", "latest activity and preview must stay paired")
    assert(
      merged.lastIncomingAt == 150 and merged.lastIncomingSender == "Canonical" and merged.lastIncomingPreview == "new incoming",
      "latest incoming sender, preview, and time must stay paired"
    )
  end

  -- test_merge_survives_missing_messages_table
  do
    local conversations = {
      ["alice-realm::BN::bar#5678"] = {
        lastActivityAt = 300,
        messages = nil, -- lost via partial SavedVariables
      },
      ["bnet::BN::bar#5678"] = {
        lastActivityAt = 100,
        messages = { { sentAt = 50, text = "kept" } },
      },
    }

    local ok, err = pcall(function()
      PrefixMigration.MigratePrefix(conversations, "::BN::", "bnet", {})
    end)
    assert(ok, "merge with a missing messages table must not crash: " .. tostring(err))

    local merged = conversations["bnet::BN::bar#5678"]
    assert(merged ~= nil, "merged conversation should exist")
    assert(#(merged.messages or {}) == 1, "the surviving message is kept; got " .. tostring(#(merged.messages or {})))
  end

  -- test_plain_rename_without_collision
  do
    local conversations = {
      ["alice-realm::WOW::bob-realm"] = { lastActivityAt = 10, messages = {} },
    }

    PrefixMigration.MigratePrefix(conversations, "::WOW::", "wow", {})

    assert(conversations["wow::WOW::bob-realm"] ~= nil, "conversation renames to the shared prefix")
    assert(conversations["alice-realm::WOW::bob-realm"] == nil, "legacy key is removed")
  end
end
