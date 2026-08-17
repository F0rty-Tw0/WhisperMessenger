local Migrations = require("WhisperMessenger.Persistence.Migrations")
local Schema = require("WhisperMessenger.Persistence.Schema")
local Store = require("WhisperMessenger.Model.ConversationStore")
local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")
local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local GroupSendPolicy = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPolicy")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")
local Composer = require("WhisperMessenger.UI.Composer")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  -- test_v4_wow_conversation_gets_canonical_WOW_channel
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

    assert(migrated.schemaVersion == Migrations.CURRENT_VERSION, "expected current schema version, got " .. tostring(migrated.schemaVersion))
    local conv = migrated.conversations["wow::WOW::arthas-area52"]
    assert(conv ~= nil, "conversation should still exist after migration")
    assert(conv.channel == "WOW", "wow:: conversation should be stamped WOW, got " .. tostring(conv.channel))
  end

  -- test_v4_bnet_conversation_gets_canonical_BN_channel
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

    assert(migrated.schemaVersion == Migrations.CURRENT_VERSION, "expected current schema version, got " .. tostring(migrated.schemaVersion))
    local conv = migrated.conversations["bnet::BN::jaina#1234"]
    assert(conv ~= nil, "bnet conversation should still exist after migration")
    assert(conv.channel == "BN", "bnet conversation should be stamped BN, got " .. tostring(conv.channel))
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

    assert(migrated.conversations["wow::WOW::foo-realm"].channel == "WOW", "wow conversation should be WOW")
    assert(migrated.conversations["bnet::BN::bar#1"].channel == "BN", "bnet conversation should be BN")
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
    assert(result.schemaVersion == Migrations.CURRENT_VERSION, "schema version should be current after migration")
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
    assert(result.schemaVersion == Migrations.CURRENT_VERSION, "schema version should be current")
  end

  -- test_schema_version_bumps_to_current_from_nil
  do
    local migrated = Migrations.Apply(nil, Schema)
    assert(migrated.schemaVersion == Migrations.CURRENT_VERSION, "fresh state should be current, got " .. tostring(migrated.schemaVersion))
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
    assert(wowConv.channel == "WOW", "legacy ::WOW:: key should be stamped WOW, got " .. tostring(wowConv.channel))
    local bnConv = migrated.conversations["alice-stormrage::BN::jaina#1234"]
    assert(bnConv.channel == "BN", "legacy ::BN:: key should be stamped BN, got " .. tostring(bnConv.channel))
  end
  -- test_already_migrated_typed_channels_normalize_idempotently
  do
    local accountState = {
      schemaVersion = 5,
      conversations = {
        ["wow::WOW::arthas-area52"] = { channel = "WHISPER", messages = {} },
        ["bnet::BN::jaina#1234"] = { channel = "BN_WHISPER", messages = {} },
      },
      contacts = {},
      pendingHydration = {},
      channelMessages = {},
    }

    Migrations.Apply(accountState, Schema)
    assert(accountState.conversations["wow::WOW::arthas-area52"].channel == "WOW", "typed whisper must normalize to WOW")
    assert(accountState.conversations["bnet::BN::jaina#1234"].channel == "BN", "typed BNet whisper must normalize to BN")

    Migrations.Apply(accountState, Schema)
    assert(accountState.conversations["wow::WOW::arthas-area52"].channel == "WOW", "second migration must keep WOW canonical")
    assert(accountState.conversations["bnet::BN::jaina#1234"].channel == "BN", "second migration must keep BN canonical")
  end

  -- test_migrated_whispers_route_through_the_real_composer_callback
  do
    local savedBNSendWhisper = _G.BNSendWhisper
    local characterSends = {}
    local bnetSends = {}
    rawset(_G, "BNSendWhisper", function(bnetAccountID, text)
      bnetSends[#bnetSends + 1] = { bnetAccountID = bnetAccountID, text = text }
      return true
    end)

    local accountState = {
      schemaVersion = 5,
      conversations = {
        ["wow::WOW::arthas-area52"] = {
          channel = "WHISPER",
          displayName = "Arthas-Area52",
          messages = {},
        },
        ["bnet::BN::jaina#1234"] = {
          channel = "BN_WHISPER",
          displayName = "Jaina#1234",
          bnetAccountID = 42,
          messages = {},
        },
      },
      contacts = {},
      pendingHydration = {},
      channelMessages = {},
    }
    Migrations.Apply(accountState, Schema)

    local store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 })
    store.conversations = accountState.conversations
    local runtime = {
      store = store,
      sendStatusByConversation = {},
      pendingOutgoing = {},
      localProfileId = "arthas-area52",
      now = function()
        return 1
      end,
      chatApi = {
        SendChatMessage = function(text, _, _, target)
          characterSends[#characterSends + 1] = { target = target, text = text }
        end,
      },
      bnetApi = {},
    }
    local callbacks = WindowCallbacks.Create({
      runtime = runtime,
      groupSendPolicy = GroupSendPolicy.Create({ runtime = runtime }),
      sendHandler = SendHandler,
      refreshWindow = function() end,
    })
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "parent", nil)
    parent:SetSize(600, 50)

    local wow = ConversationSnapshot.Build("wow::WOW::arthas-area52", store.conversations["wow::WOW::arthas-area52"])
    local wowComposer = Composer.Create(factory, parent, wow, callbacks.onSend, function() end, nil)
    wowComposer.input:SetText("character route")
    wowComposer.input.scripts.OnEnterPressed(wowComposer.input)
    assert(#characterSends == 1 and characterSends[1].target == "Arthas-Area52", "migrated WOW conversation must use character transport")
    assert(#bnetSends == 0, "migrated WOW conversation must not use BNet transport")

    local bnet = ConversationSnapshot.Build("bnet::BN::jaina#1234", store.conversations["bnet::BN::jaina#1234"])
    local bnetComposer = Composer.Create(factory, parent, bnet, callbacks.onSend, function() end, nil)
    bnetComposer.input:SetText("bnet route")
    bnetComposer.input.scripts.OnEnterPressed(bnetComposer.input)
    assert(#characterSends == 1, "migrated BNet conversation must not use character transport")
    assert(#bnetSends == 1 and bnetSends[1].bnetAccountID == 42, "migrated BNet conversation must use BNet transport")

    rawset(_G, "BNSendWhisper", savedBNSendWhisper)
  end
end
