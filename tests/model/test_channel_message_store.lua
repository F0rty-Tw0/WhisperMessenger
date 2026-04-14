local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

return function()
  -- test_record_and_get_latest
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Arthas-Area52", "WTS [Thunderfury] 50k", "Trade", 1000)

    local entry = ChannelMessageStore.GetLatest(state, "arthas-area52")
    assert(entry ~= nil, "should find entry by canonical name")
    assert(entry.text == "WTS [Thunderfury] 50k", "text mismatch: " .. tostring(entry.text))
    assert(entry.channelLabel == "Trade", "channelLabel mismatch: " .. tostring(entry.channelLabel))
    assert(entry.playerName == "Arthas-Area52", "playerName mismatch: " .. tostring(entry.playerName))
    assert(entry.sentAt == 1000, "sentAt mismatch: " .. tostring(entry.sentAt))
  end

  -- test_get_latest_returns_nil_for_unknown_player
  do
    local state = ChannelMessageStore.New()
    local entry = ChannelMessageStore.GetLatest(state, "nobody-realm")
    assert(entry == nil, "should return nil for unknown player")
  end

  -- test_upsert_newer_replaces_older
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Arthas-Area52", "old message", "General", 1000)
    ChannelMessageStore.Record(state, "Arthas-Area52", "new message", "Trade", 2000)

    local entry = ChannelMessageStore.GetLatest(state, "arthas-area52")
    assert(entry.text == "new message", "should have newer message, got: " .. tostring(entry.text))
    assert(entry.channelLabel == "Trade", "channel should be updated")
  end

  -- test_older_message_does_not_replace_newer
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Arthas-Area52", "newer message", "Trade", 2000)
    ChannelMessageStore.Record(state, "Arthas-Area52", "older message", "General", 1000)

    local entry = ChannelMessageStore.GetLatest(state, "arthas-area52")
    assert(entry.text == "newer message", "should keep newer message, got: " .. tostring(entry.text))
  end

  -- test_base_name_fallback_lookup
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Jaina-Proudmoore", "LFG Mythic+", "LookingForGroup", 1000)

    -- Exact match works
    local exact = ChannelMessageStore.GetLatest(state, "jaina-proudmoore")
    assert(exact ~= nil, "exact match should work")

    -- Base name fallback works (same-realm name without realm suffix)
    local fallback = ChannelMessageStore.GetLatest(state, "jaina")
    assert(fallback ~= nil, "base name fallback should work")
    assert(fallback.text == "LFG Mythic+", "fallback text mismatch")
  end

  -- test_base_name_fallback_from_short_sender
  do
    local state = ChannelMessageStore.New()
    -- Sender name without realm (same-realm)
    ChannelMessageStore.Record(state, "Thrall", "WTB leather", "Trade", 1000)

    -- Lookup with full canonical name should fall back to base name
    local entry = ChannelMessageStore.GetLatest(state, "thrall-area52")
    assert(entry ~= nil, "should find via base name fallback from full canonical")
    assert(entry.text == "WTB leather", "text mismatch on fallback")
  end

  -- test_expiry_filters_stale_entries
  do
    local state = ChannelMessageStore.New()
    local now = 5000
    local staleTime = now - 1801 -- 30 min + 1 second ago
    ChannelMessageStore.Record(state, "Arthas-Area52", "old post", "Trade", staleTime)

    local entry = ChannelMessageStore.GetLatest(state, "arthas-area52", now)
    assert(entry == nil, "should filter expired entry (30min TTL)")
  end

  -- test_fresh_entry_not_expired
  do
    local state = ChannelMessageStore.New()
    local now = 5000
    local freshTime = now - 1799 -- just under 30 min
    ChannelMessageStore.Record(state, "Arthas-Area52", "fresh post", "Trade", freshTime)

    local entry = ChannelMessageStore.GetLatest(state, "arthas-area52", now)
    assert(entry ~= nil, "fresh entry should not be expired")
    assert(entry.text == "fresh post", "text mismatch")
  end

  -- test_eviction_at_cap
  do
    local state = ChannelMessageStore.New({ maxEntries = 3 })
    ChannelMessageStore.Record(state, "Player1-Realm", "msg1", "Trade", 100)
    ChannelMessageStore.Record(state, "Player2-Realm", "msg2", "Trade", 200)
    ChannelMessageStore.Record(state, "Player3-Realm", "msg3", "Trade", 300)
    ChannelMessageStore.Record(state, "Player4-Realm", "msg4", "Trade", 400)

    -- Oldest (Player1) should be evicted
    local evicted = ChannelMessageStore.GetLatest(state, "player1-realm")
    assert(evicted == nil, "oldest entry should be evicted at cap")

    -- Newest entries should survive
    local kept = ChannelMessageStore.GetLatest(state, "player4-realm")
    assert(kept ~= nil, "newest entry should survive eviction")
    assert(kept.text == "msg4", "newest text mismatch")
  end

  -- test_case_insensitive_lookup
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "ARTHAS-AREA52", "msg", "Trade", 1000)

    local entry = ChannelMessageStore.GetLatest(state, "arthas-area52")
    assert(entry ~= nil, "lookup should be case-insensitive")
  end

  -- test_multiple_players_independent
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Arthas-Area52", "sell stuff", "Trade", 1000)
    ChannelMessageStore.Record(state, "Jaina-Proudmoore", "LFG keys", "LookingForGroup", 2000)

    local a = ChannelMessageStore.GetLatest(state, "arthas-area52")
    local j = ChannelMessageStore.GetLatest(state, "jaina-proudmoore")
    assert(a.text == "sell stuff", "Arthas message mismatch")
    assert(j.text == "LFG keys", "Jaina message mismatch")
  end

  -- test_restore_rebuilds_indexes_and_prunes_expired_entries
  do
    local restored = ChannelMessageStore.Restore({
      entries = {
        ["arthas-area52"] = {
          text = "fresh post",
          channelLabel = "Trade",
          playerName = "Arthas-Area52",
          sentAt = 5000,
        },
        ["jaina-proudmoore"] = {
          text = "stale post",
          channelLabel = "General",
          playerName = "Jaina-Proudmoore",
          sentAt = 1000,
        },
      },
    }, nil, 6000)

    local fresh = ChannelMessageStore.GetLatest(restored, "arthas")
    local stale = ChannelMessageStore.GetLatest(restored, "jaina-proudmoore", 6000)

    assert(fresh ~= nil, "fresh entry should survive restore")
    assert(fresh.text == "fresh post", "restored text mismatch")
    assert(stale == nil, "expired entry should be pruned during restore")
  end

  -- test_record_assigns_sequence_for_equal_timestamp_tiebreaks
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Thrall-Area52", "area52 post", "Trade", 1000)
    ChannelMessageStore.Record(state, "Thrall-Draenor", "draenor post", "Trade", 1000)

    local first = state.entries["thrall-area52"]
    local second = state.entries["thrall-draenor"]
    assert(type(first.sequence) == "number", "first entry should record a sequence number")
    assert(type(second.sequence) == "number", "second entry should record a sequence number")
    assert(second.sequence > first.sequence, "later entry should have a higher sequence number")
  end

  -- test_restore_uses_sequence_for_equal_timestamp_base_fallback
  do
    local restored = ChannelMessageStore.Restore({
      nextSequence = 2,
      entries = {
        ["thrall-area52"] = {
          text = "area52 post",
          channelLabel = "Trade",
          playerName = "Thrall-Area52",
          sentAt = 1000,
          sequence = 1,
        },
        ["thrall-draenor"] = {
          text = "draenor post",
          channelLabel = "Trade",
          playerName = "Thrall-Draenor",
          sentAt = 1000,
          sequence = 2,
        },
      },
    }, nil, 1000)

    local entry = ChannelMessageStore.GetLatest(restored, "thrall", 1000)
    assert(entry ~= nil, "expected base-name fallback to survive restore")
    assert(entry.text == "draenor post", "restore should prefer the higher sequence for equal timestamps")
  end
end
