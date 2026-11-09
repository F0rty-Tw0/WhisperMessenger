local ChannelMessageStore = require("WhisperMessenger.Model.ChannelMessageStore")

return function()
  -- test_realm_lookup_ignores_same_name_from_another_realm
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Thrall-Draenor", "WTS ore", "Trade", 1000)

    local entry = ChannelMessageStore.GetLatest(state, "thrall-area52")
    assert(entry == nil, "a realm lookup must not take another realm's line, got: " .. tostring(entry and entry.text))
  end

  -- test_realm_lookup_finds_the_same_realm_line
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Thrall-Area52", "WTS ore", "Trade", 1000)

    local entry = ChannelMessageStore.GetLatest(state, "thrall-area52")
    assert(entry and entry.text == "WTS ore", "same realm should match, got: " .. tostring(entry and entry.text))
  end

  -- test_realm_lookup_falls_back_to_a_realmless_line
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Thrall", "WTS ore", "Trade", 1000)

    local entry = ChannelMessageStore.GetLatest(state, "thrall-area52")
    assert(entry and entry.text == "WTS ore", "a realm-less line should match, got: " .. tostring(entry and entry.text))
  end

  -- test_realmless_lookup_takes_newest_from_any_realm
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Thrall-Draenor", "draenor line", "Trade", 1000)
    ChannelMessageStore.Record(state, "Thrall-Area52", "area line", "Trade", 2000)

    local entry = ChannelMessageStore.GetLatest(state, "thrall")
    assert(entry and entry.text == "area line", "newest line should win, got: " .. tostring(entry and entry.text))
  end

  -- test_realm_spaces_hyphens_and_apostrophes_match
  do
    local state = ChannelMessageStore.New()
    ChannelMessageStore.Record(state, "Thrall-Area52", "area line", "Trade", 1000)
    ChannelMessageStore.Record(state, "Jaina-AzjolNerub", "azjol line", "Trade", 1000)
    ChannelMessageStore.Record(state, "Arthas-Kel'Thuzad", "kel line", "Trade", 1000)

    local spaced = ChannelMessageStore.GetLatest(state, "thrall-area 52")
    assert(spaced and spaced.text == "area line", "a spaced realm should match")
    local hyphenated = ChannelMessageStore.GetLatest(state, "jaina-azjol-nerub")
    assert(hyphenated and hyphenated.text == "azjol line", "a hyphenated realm should match")
    local apostrophe = ChannelMessageStore.GetLatest(state, "arthas-kelthuzad")
    assert(apostrophe and apostrophe.text == "kel line", "an apostrophe realm should match")
  end

  -- test_realm_lookup_prefers_the_realmless_line_over_another_realm
  do
    for _, realmlessFirst in ipairs({ true, false }) do
      local state = ChannelMessageStore.New()
      local realmlessAt = realmlessFirst and 1000 or 2000
      local otherAt = realmlessFirst and 2000 or 1000
      ChannelMessageStore.Record(state, "Thrall", "realmless line", "Trade", realmlessAt)
      ChannelMessageStore.Record(state, "Thrall-Draenor", "draenor line", "Trade", otherAt)

      local entry = ChannelMessageStore.GetLatest(state, "thrall-area52")
      assert(entry and entry.text == "realmless line", "the realm-less line should win, got: " .. tostring(entry and entry.text))
    end
  end

  -- test_restore_merges_keys_that_normalize_alike_keeping_the_newer
  do
    local newLine = { text = "new", channelLabel = "Trade", playerName = "Thrall-Area 52", sentAt = 2000, sequence = 2 }
    local oldLine = { text = "old", channelLabel = "Trade", playerName = "Thrall-Area52", sentAt = 1000, sequence = 1 }
    local fixtures = {
      { ["Thrall-Area 52"] = newLine, ["Thrall-Area52"] = oldLine },
      { ["Thrall-Area 52"] = oldLine, ["Thrall-Area52"] = newLine },
    }
    for index, entries in ipairs(fixtures) do
      local restored = ChannelMessageStore.Restore({ entries = entries })
      assert(restored.entryCount == 1, "fixture " .. index .. " should count one key, got: " .. tostring(restored.entryCount))
      local entry = ChannelMessageStore.GetLatest(restored, "thrall-area52")
      assert(entry and entry.text == "new", "fixture " .. index .. " should keep the newer line, got: " .. tostring(entry and entry.text))
    end
  end
end
