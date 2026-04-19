local EphemeralPurge = require("WhisperMessenger.Model.EphemeralPurge")

return function()
  -- test_purge_all_empty_store_returns_zero
  do
    local state = { conversations = {} }
    local count = EphemeralPurge.PurgeAll(state)
    assert(count == 0, "expected 0 removals from empty store, got: " .. tostring(count))
  end

  -- test_purge_all_removes_ephemeral_keeps_persistent
  do
    local state = {
      conversations = {
        ["whisper::Alice"] = { channel = "WHISPER" },
        ["bnconv::1"] = { channel = "BN_CONVERSATION" },
        ["party::Bob"] = { channel = "PARTY" },
        ["instance::Charlie"] = { channel = "INSTANCE_CHAT" },
      },
    }
    local count = EphemeralPurge.PurgeAll(state)
    assert(count == 2, "expected 2 removals, got: " .. tostring(count))
    assert(state.conversations["whisper::Alice"] ~= nil, "WHISPER should be kept")
    assert(state.conversations["bnconv::1"] ~= nil, "BN_CONVERSATION should be kept")
    assert(state.conversations["party::Bob"] == nil, "PARTY should be removed")
    assert(state.conversations["instance::Charlie"] == nil, "INSTANCE_CHAT should be removed")
  end

  -- test_purge_all_treats_nil_channel_as_persistent
  do
    local state = {
      conversations = {
        ["legacy::Dave"] = { channel = nil },
        ["party::Eve"] = { channel = "PARTY" },
      },
    }
    local count = EphemeralPurge.PurgeAll(state)
    assert(count == 1, "expected 1 removal, got: " .. tostring(count))
    assert(state.conversations["legacy::Dave"] ~= nil, "nil-channel conversation should be kept")
    assert(state.conversations["party::Eve"] == nil, "PARTY should be removed")
  end

  -- test_purge_by_channel_removes_only_party
  do
    local state = {
      conversations = {
        ["party::Alice"] = { channel = "PARTY" },
        ["instance::Bob"] = { channel = "INSTANCE_CHAT" },
        ["whisper::Carol"] = { channel = "WHISPER" },
      },
    }
    local count = EphemeralPurge.PurgeByChannel(state, { PARTY = true })
    assert(count == 1, "expected 1 removal, got: " .. tostring(count))
    assert(state.conversations["party::Alice"] == nil, "PARTY should be removed")
    assert(state.conversations["instance::Bob"] ~= nil, "INSTANCE_CHAT should remain")
    assert(state.conversations["whisper::Carol"] ~= nil, "WHISPER should remain")
  end

  -- test_purge_by_channel_empty_set_removes_nothing
  do
    local state = {
      conversations = {
        ["party::Alice"] = { channel = "PARTY" },
        ["instance::Bob"] = { channel = "INSTANCE_CHAT" },
      },
    }
    local count = EphemeralPurge.PurgeByChannel(state, {})
    assert(count == 0, "expected 0 removals with empty set, got: " .. tostring(count))
    assert(state.conversations["party::Alice"] ~= nil, "PARTY should remain with empty set")
    assert(state.conversations["instance::Bob"] ~= nil, "INSTANCE_CHAT should remain with empty set")
  end

  -- test_purge_all_clears_active_conversation_key_when_purged
  do
    local state = {
      conversations = {
        ["party::Alice"] = { channel = "PARTY" },
      },
      activeConversationKey = "party::Alice",
    }
    EphemeralPurge.PurgeAll(state)
    assert(state.activeConversationKey == nil, "activeConversationKey should be cleared when active conv is purged")
  end

  -- test_purge_all_leaves_active_key_intact_when_not_purged
  do
    local state = {
      conversations = {
        ["whisper::Alice"] = { channel = "WHISPER" },
        ["party::Bob"] = { channel = "PARTY" },
      },
      activeConversationKey = "whisper::Alice",
    }
    EphemeralPurge.PurgeAll(state)
    assert(
      state.activeConversationKey == "whisper::Alice",
      "activeConversationKey should stay when active conv is kept"
    )
  end

  -- test_purge_all_nil_state_is_safe_noop
  do
    local count = EphemeralPurge.PurgeAll(nil)
    assert(count == 0, "expected 0 from nil state, got: " .. tostring(count))
  end

  -- test_purge_all_keeps_legacy_wow_and_bn_channel_strings
  -- Regression: Identity.FromWhisper / FromBattleNet stamp conv.channel =
  -- "WOW" / "BN" at live-message time. These are NOT ChannelType constants
  -- ("WHISPER" / "BN_WHISPER") but represent persistent whisper threads. Purging
  -- them on logout wipes the user's whisper history — that is data loss.
  do
    local state = {
      conversations = {
        ["wow::WOW::alice"] = { channel = "WOW" },
        ["bnet::BN::bob#1234"] = { channel = "BN" },
        ["party::me"] = { channel = "PARTY" },
      },
    }
    local count = EphemeralPurge.PurgeAll(state)
    assert(count == 1, "expected only PARTY removed, got: " .. tostring(count))
    assert(state.conversations["wow::WOW::alice"] ~= nil, 'legacy "WOW" channel must be kept')
    assert(state.conversations["bnet::BN::bob#1234"] ~= nil, 'legacy "BN" channel must be kept')
    assert(state.conversations["party::me"] == nil, "PARTY should be removed")
  end

  -- test_purge_all_keeps_unknown_channel_values_defensively
  -- Any channel value we don't explicitly know as ephemeral must be kept.
  do
    local state = {
      conversations = {
        ["guild::me"] = { channel = "GUILD" },
        ["officer::me"] = { channel = "OFFICER" },
        ["channel::me::General"] = { channel = "CHANNEL" },
        ["community::1::2"] = { channel = "COMMUNITY" },
        ["future::thing"] = { channel = "SOMETHING_BRAND_NEW" },
        ["party::me"] = { channel = "PARTY" },
      },
    }
    local count = EphemeralPurge.PurgeAll(state)
    assert(count == 1, "only PARTY should be removed, got: " .. tostring(count))
    assert(state.conversations["guild::me"] ~= nil, "GUILD must be kept")
    assert(state.conversations["officer::me"] ~= nil, "OFFICER must be kept")
    assert(state.conversations["channel::me::General"] ~= nil, "CHANNEL must be kept")
    assert(state.conversations["community::1::2"] ~= nil, "COMMUNITY must be kept")
    assert(state.conversations["future::thing"] ~= nil, "unknown channel must be kept defensively")
  end
end
