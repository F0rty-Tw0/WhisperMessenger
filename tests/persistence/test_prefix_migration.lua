local PrefixMigration = require("WhisperMessenger.Persistence.SavedState.PrefixMigration")

return function()
  -- test_merge_sorts_combined_messages_chronologically
  do
    local conversations = {
      ["alice-realm::BN::foo#1234"] = {
        lastActivityAt = 200,
        messages = { { sentAt = 150, text = "late-a" }, { sentAt = 200, text = "late-b" } },
      },
      ["bnet::BN::foo#1234"] = {
        lastActivityAt = 100,
        messages = { { sentAt = 50, text = "early-a" }, { sentAt = 100, text = "early-b" } },
      },
    }

    PrefixMigration.MigratePrefix(conversations, "::BN::", "bnet", {})

    local merged = conversations["bnet::BN::foo#1234"]
    assert(merged ~= nil, "merged conversation should exist under the new key")
    assert(conversations["alice-realm::BN::foo#1234"] == nil, "legacy key should be removed")
    assert(#merged.messages == 4, "all messages survive the merge; got " .. tostring(#merged.messages))
    for i = 2, #merged.messages do
      assert(
        (merged.messages[i - 1].sentAt or 0) <= (merged.messages[i].sentAt or 0),
        "merged messages must be chronological; position " .. i .. " is out of order"
      )
    end
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
