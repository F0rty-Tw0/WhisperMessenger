local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

local function textOf(state, name, now)
  local entry = ChannelMessageStore.GetLatest(state, name, now)
  return entry and entry.text or nil
end

return function()
  -- test_eviction_drops_oldest_sent_at_not_first_inserted
  do
    local state = ChannelMessageStore.New({ maxEntries = 3 })
    ChannelMessageStore.Record(state, "A-Realm", "a", "Trade", 300)
    ChannelMessageStore.Record(state, "B-Realm", "b", "Trade", 100)
    ChannelMessageStore.Record(state, "C-Realm", "c", "Trade", 200)
    ChannelMessageStore.Record(state, "D-Realm", "d", "Trade", 400)

    assert(textOf(state, "b-realm") == nil, "the line with the oldest time should be evicted first")
    assert(textOf(state, "a-realm") == "a", "a line inserted first but sent later should survive")

    ChannelMessageStore.Record(state, "E-Realm", "e", "Trade", 500)
    assert(textOf(state, "c-realm") == nil, "the next oldest line should be evicted next")
    assert(textOf(state, "a-realm") == "a", "a newer line should still survive")
  end

  -- test_eviction_breaks_equal_sent_at_ties_by_arrival
  do
    local state = ChannelMessageStore.New({ maxEntries = 2 })
    ChannelMessageStore.Record(state, "A-Realm", "a", "Trade", 100)
    ChannelMessageStore.Record(state, "B-Realm", "b", "Trade", 100)
    ChannelMessageStore.Record(state, "C-Realm", "c", "Trade", 100)

    assert(textOf(state, "a-realm") == nil, "the first of equal-time lines should be evicted")
    assert(textOf(state, "b-realm") == "b", "the later equal-time line should survive")
  end

  -- test_replaced_line_ages_from_its_new_time
  do
    local state = ChannelMessageStore.New({ maxEntries = 2 })
    ChannelMessageStore.Record(state, "A-Realm", "a1", "Trade", 100)
    ChannelMessageStore.Record(state, "B-Realm", "b", "Trade", 200)
    ChannelMessageStore.Record(state, "A-Realm", "a2", "Trade", 300)
    ChannelMessageStore.Record(state, "C-Realm", "c", "Trade", 400)

    assert(textOf(state, "b-realm") == nil, "the sender who posted longest ago should be evicted")
    assert(textOf(state, "a-realm") == "a2", "a sender who posted again should keep the newer line")
    assert(state.entryCount == 2, "entry count should match the cap, got " .. tostring(state.entryCount))
  end

  -- test_many_reposts_below_cap_keep_one_entry_per_sender
  do
    local state = ChannelMessageStore.New({ maxEntries = 3 })
    for i = 1, 500 do
      ChannelMessageStore.Record(state, "A-Realm", "a" .. i, "Trade", i * 3)
      ChannelMessageStore.Record(state, "B-Realm", "b" .. i, "Trade", i * 3 + 1)
    end
    ChannelMessageStore.Record(state, "C-Realm", "c", "Trade", 2000)
    ChannelMessageStore.Record(state, "D-Realm", "d", "Trade", 2001)

    assert(textOf(state, "a-realm") == nil, "the sender who posted longest ago should be evicted")
    assert(textOf(state, "b-realm") == "b500", "the newer repeat poster should keep the last line")
    assert(state.entryCount == 3, "entry count should match the cap, got " .. tostring(state.entryCount))
  end

  -- test_base_fallback_after_eviction_points_to_surviving_realm
  do
    local state = ChannelMessageStore.New({ maxEntries = 2 })
    ChannelMessageStore.Record(state, "Thrall-Draenor", "draenor post", "Trade", 100)
    ChannelMessageStore.Record(state, "Thrall-Area52", "area52 post", "Trade", 200)
    ChannelMessageStore.Record(state, "Jaina-Proudmoore", "jaina post", "Trade", 300)
    assert(textOf(state, "thrall") == "area52 post", "fallback should still find the surviving realm")

    ChannelMessageStore.Record(state, "Vol-Realm", "vol post", "Trade", 400)
    assert(textOf(state, "thrall") == nil, "fallback should find nothing once every realm is evicted")
  end

  -- test_base_fallback_uses_older_realm_after_newest_realm_expires
  do
    local state = ChannelMessageStore.New({ ttl = 50 })
    ChannelMessageStore.Record(state, "Thrall-Area52", "area52 post", "Trade", 100)
    ChannelMessageStore.Record(state, "Thrall-Draenor", "draenor post", "Trade", 200)

    assert(textOf(state, "thrall-draenor", 300) == nil, "the expired newest realm should be dropped")
    assert(textOf(state, "thrall") == "area52 post", "fallback should move to the remaining realm")
  end

  -- test_base_fallback_expiry_removes_the_matched_entry
  do
    local state = ChannelMessageStore.New({ ttl = 50 })
    ChannelMessageStore.Record(state, "Thrall-Area52", "area52 post", "Trade", 100)

    assert(textOf(state, "thrall", 200) == nil, "an expired fallback match should not be returned")
    assert(state.entryCount == 0, "the expired fallback match should be removed")
    assert(textOf(state, "thrall-area52") == nil, "the expired entry should be gone for exact lookups too")
  end

  -- test_restore_round_trip_keeps_eviction_order
  do
    local state = ChannelMessageStore.New({ maxEntries = 3 })
    ChannelMessageStore.Record(state, "A-Realm", "a", "Trade", 200)
    ChannelMessageStore.Record(state, "B-Realm", "b", "Trade", 100)
    ChannelMessageStore.Record(state, "C-Realm", "c", "Trade", 300)

    local restored = ChannelMessageStore.Restore(state, { maxEntries = 3 }, 300)
    assert(restored.nextSequence == state.nextSequence, "restore should keep the sequence counter")
    ChannelMessageStore.Record(restored, "D-Realm", "d", "Trade", 400)

    assert(textOf(restored, "b-realm") == nil, "the oldest restored line should be evicted first")
    assert(textOf(restored, "a-realm") == "a", "newer restored lines should survive")
    assert(textOf(restored, "c-realm") == "c", "newer restored lines should survive")
    assert(textOf(restored, "a") == "a", "restored lines should be reachable by base name")
  end

  -- test_restore_over_cap_keeps_newest_entries
  do
    local restored = ChannelMessageStore.Restore({
      entries = {
        ["a-realm"] = { text = "a", sentAt = 400, sequence = 1 },
        ["b-realm"] = { text = "b", sentAt = 100, sequence = 2 },
        ["c-realm"] = { text = "c", sentAt = 300, sequence = 3 },
        ["d-realm"] = { text = "d", sentAt = 200, sequence = 4 },
      },
    }, { maxEntries = 2 }, 400)

    assert(restored.entryCount == 2, "restore should trim to the cap")
    assert(textOf(restored, "a-realm") == "a" and textOf(restored, "c-realm") == "c", "the two newest should survive")
  end

  -- test_saved_store_holds_no_derived_indexes
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Thrall-Area52", "post", "Trade", 100)
    local persisted = { entries = true, entryCount = true, maxEntries = true, ttl = true, nextSequence = true }
    for field in pairs(state) do
      assert(persisted[field], "derived index should not be saved with the store: " .. tostring(field))
    end
  end

  -- test_record_at_cap_does_not_scan_entries
  do
    local state = ChannelMessageStore.New({ maxEntries = 50 })
    for i = 1, 50 do
      ChannelMessageStore.Record(state, "Warm" .. i .. "-Realm", "warm", "Trade", i)
    end

    local realPairs = _G.pairs
    local scans = 0
    _G.pairs = function(t)
      if t == state.entries then
        scans = scans + 1
      end
      return realPairs(t)
    end
    local ok, err = pcall(function()
      for i = 1, 100 do
        ChannelMessageStore.Record(state, "Player" .. i .. "-Realm", "msg", "Trade", 100 + i)
        ChannelMessageStore.GetLatest(state, "player" .. i)
      end
    end)
    _G.pairs = realPairs

    assert(ok, err)
    assert(scans == 0, "recording at the cap should not scan every entry, scanned " .. scans .. " times")
  end
end
