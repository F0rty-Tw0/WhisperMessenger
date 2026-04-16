local Migrations = require("WhisperMessenger.Persistence.Migrations")
local Schema = require("WhisperMessenger.Persistence.Schema")

return function()
  -- test_legacy_per_profile_channel_messages_flatten
  do
    local accountState = {
      schemaVersion = 3,
      conversations = {},
      contacts = {},
      pendingHydration = {},
      channelMessages = {
        ["arthas-area52"] = {
          nextSequence = 2,
          entries = {
            ["traderjoe-area52"] = {
              text = "WTS [Thunderfury] 50k",
              channelLabel = "Trade",
              playerName = "Traderjoe-Area52",
              sentAt = 1000,
              sequence = 1,
            },
            ["healjaina-area52"] = {
              text = "LFG Mythic+",
              channelLabel = "LookingForGroup",
              playerName = "Healjaina-Area52",
              sentAt = 2000,
              sequence = 2,
            },
          },
        },
        ["thrall-draenor"] = {
          nextSequence = 3,
          entries = {
            ["traderjoe-area52"] = {
              -- same sender as on arthas, but newer — newest should win on merge
              text = "WTS [Sulfuras] 80k",
              channelLabel = "Trade",
              playerName = "Traderjoe-Area52",
              sentAt = 4000,
              sequence = 3,
            },
          },
        },
      },
    }

    local migrated = Migrations.Apply(accountState, Schema)

    assert(type(migrated.channelMessages) == "table", "channelMessages should remain a table")
    assert(
      type(migrated.channelMessages.entries) == "table",
      "channelMessages should be flattened to the {entries, nextSequence} shape"
    )

    local flatEntries = migrated.channelMessages.entries
    assert(flatEntries["healjaina-area52"] ~= nil, "expected LFG entry to survive flattening")
    assert(flatEntries["healjaina-area52"].text == "LFG Mythic+", "LFG text mismatch after flatten")

    assert(flatEntries["traderjoe-area52"] ~= nil, "expected shared sender entry to survive flattening")
    assert(
      flatEntries["traderjoe-area52"].text == "WTS [Sulfuras] 80k",
      "expected newer entry to win merge: got " .. tostring(flatEntries["traderjoe-area52"].text)
    )

    assert(
      type(migrated.channelMessages.nextSequence) == "number",
      "expected nextSequence to be copied into flat shape"
    )
    assert(
      migrated.channelMessages.nextSequence >= 3,
      "expected nextSequence >= max legacy sequence, got " .. tostring(migrated.channelMessages.nextSequence)
    )
  end

  -- test_flat_channel_messages_unchanged
  do
    local existing = {
      entries = {
        ["thrall-area52"] = {
          text = "msg",
          channelLabel = "Trade",
          playerName = "Thrall-Area52",
          sentAt = 1000,
          sequence = 1,
        },
      },
      nextSequence = 1,
    }
    local accountState = {
      schemaVersion = 4,
      conversations = {},
      contacts = {},
      pendingHydration = {},
      channelMessages = existing,
    }

    local migrated = Migrations.Apply(accountState, Schema)
    assert(migrated.channelMessages == existing, "flat shape should not be reflattened or replaced")
    assert(migrated.channelMessages.entries["thrall-area52"].text == "msg", "entry should survive migration")
  end

  -- test_empty_channel_messages_ok
  do
    local accountState = Schema.NewAccountState()
    local migrated = Migrations.Apply(accountState, Schema)
    assert(type(migrated.channelMessages) == "table", "empty channelMessages should remain a table")
  end
end
