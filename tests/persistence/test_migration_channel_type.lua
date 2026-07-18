local Migrations = require("WhisperMessenger.Persistence.Migrations")
local Schema = require("WhisperMessenger.Persistence.Schema")

return function()
  -- test_v4_wow_conversation_gets_WHISPER_channel
  do
    local accountState = {
      schemaVersion = 4,
      conversations = {
        ["wow::WOW::arthas-area52"] = { messages = {} },
      },
      contacts = {},
      pendingHydration = {},
      channelMessages = {},
    }

    local migrated = Migrations.Apply(accountState, Schema)

    assert(migrated.schemaVersion == 5, "expected schemaVersion 5, got " .. tostring(migrated.schemaVersion))
    local conv = migrated.conversations["wow::WOW::arthas-area52"]
    assert(conv ~= nil, "conversation should still exist after migration")
    assert(conv.channel == "WHISPER", "wow:: conversation should be stamped WHISPER, got " .. tostring(conv.channel))
  end

  -- test_v4_bnet_conversation_gets_BN_WHISPER_channel
  do
    local accountState = {
      schemaVersion = 4,
      conversations = {
        ["bnet::BN::jaina#1234"] = { messages = {} },
      },
      contacts = {},
      pendingHydration = {},
      channelMessages = {},
    }

    local migrated = Migrations.Apply(accountState, Schema)

    assert(migrated.schemaVersion == 5, "expected schemaVersion 5, got " .. tostring(migrated.schemaVersion))
    local conv = migrated.conversations["bnet::BN::jaina#1234"]
    assert(conv ~= nil, "bnet conversation should still exist after migration")
    assert(conv.channel == "BN_WHISPER", "bnet:: conversation should be stamped BN_WHISPER, got " .. tostring(conv.channel))
  end

  -- test_mixed_v4_state_stamps_both_types
  do
    local accountState = {
      schemaVersion = 4,
      conversations = {
        ["wow::WOW::foo-realm"] = { messages = {} },
        ["bnet::BN::bar#1"] = { messages = {} },
      },
      contacts = {},
      pendingHydration = {},
      channelMessages = {},
    }

    local migrated = Migrations.Apply(accountState, Schema)

    assert(migrated.conversations["wow::WOW::foo-realm"].channel == "WHISPER", "wow conversation should be WHISPER")
    assert(migrated.conversations["bnet::BN::bar#1"].channel == "BN_WHISPER", "bnet conversation should be BN_WHISPER")
  end

  -- test_already_stamped_records_are_preserved
  do
    local accountState = {
      schemaVersion = 4,
      conversations = {
        ["wow::WOW::somechar-realm"] = { messages = {}, channel = "GUILD" },
      },
      contacts = {},
      pendingHydration = {},
      channelMessages = {},
    }

    local migrated = Migrations.Apply(accountState, Schema)

    assert(
      migrated.conversations["wow::WOW::somechar-realm"].channel == "GUILD",
      "existing channel value should not be overwritten, got " .. tostring(migrated.conversations["wow::WOW::somechar-realm"].channel)
    )
  end

  -- test_empty_conversations_does_not_crash
  do
    local accountState = {
      schemaVersion = 4,
      conversations = {},
      contacts = {},
      pendingHydration = {},
      channelMessages = {},
    }

    local ok, result = pcall(Migrations.Apply, accountState, Schema)
    assert(ok, "migration should not crash on empty conversations: " .. tostring(result))
    assert(result.schemaVersion == 5, "schema version should be 5 after migration")
  end

  -- test_nil_conversations_does_not_crash
  do
    local accountState = {
      schemaVersion = 4,
      conversations = nil,
      contacts = {},
      pendingHydration = {},
      channelMessages = {},
    }

    local ok, result = pcall(Migrations.Apply, accountState, Schema)
    assert(ok, "migration should not crash when conversations is nil: " .. tostring(result))
    assert(result.schemaVersion == 5, "schema version should be 5")
  end

  -- test_schema_version_bumps_to_5_from_nil
  do
    local migrated = Migrations.Apply(nil, Schema)
    assert(migrated.schemaVersion == 5, "fresh state should be at version 5, got " .. tostring(migrated.schemaVersion))
  end

  -- test_legacy_prefixed_keys_get_channel_backfill
  -- Migrations.Apply runs BEFORE PrefixMigration renames legacy per-character
  -- keys, so the backfill must recognize the pre-rename key shapes too —
  -- otherwise upgraded conversations run a whole session with channel=nil.
  do
    local accountState = {
      schemaVersion = 4,
      conversations = {
        ["alice-stormrage::WOW::bob-stormrage"] = { messages = {} },
        ["alice-stormrage::BN::jaina#1234"] = { messages = {} },
      },
      contacts = {},
      pendingHydration = {},
      channelMessages = {},
    }

    local migrated = Migrations.Apply(accountState, Schema)

    local wowConv = migrated.conversations["alice-stormrage::WOW::bob-stormrage"]
    assert(wowConv.channel == "WHISPER", "legacy ::WOW:: key should be stamped WHISPER, got " .. tostring(wowConv.channel))
    local bnConv = migrated.conversations["alice-stormrage::BN::jaina#1234"]
    assert(bnConv.channel == "BN_WHISPER", "legacy ::BN:: key should be stamped BN_WHISPER, got " .. tostring(bnConv.channel))
  end
end
