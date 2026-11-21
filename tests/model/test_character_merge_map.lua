local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")

-- Which character chats are folded into a Battle.net chat, and which the
-- player separated for good. Both maps are account-wide saved tables.
local K = "wow::WOW::arthas"
local K_OTHER_REALM = "wow::WOW::arthas-area52"
local B = "bnet::BN::friend#1234"
local B_OTHER = "bnet::BN::other#5678"

local function fresh()
  return CharacterMergeMap.Ensure({})
end

return function()
  -- test_ensure_creates_both_saved_tables
  do
    local accountState = {}
    local merges = CharacterMergeMap.Ensure(accountState)
    assert(type(accountState.mergedCharacters) == "table" and type(accountState.separatedCharacters) == "table", "both saved tables exist")
    assert(
      merges.merged == accountState.mergedCharacters and merges.separated == accountState.separatedCharacters,
      "the handle shares the saved tables"
    )
  end

  -- test_ensure_keeps_saved_entries
  do
    local accountState = { mergedCharacters = { [K] = { bnetKey = B, name = "Arthas" } }, separatedCharacters = { [K_OTHER_REALM] = true } }
    local merges = CharacterMergeMap.Ensure(accountState)
    assert(CharacterMergeMap.Get(merges, K).bnetKey == B, "a saved merge survives a reload")
    assert(CharacterMergeMap.IsSeparated(merges, K_OTHER_REALM) == true, "a saved separation survives a reload")
  end

  -- test_ensure_replaces_a_saved_value_that_is_not_a_table
  do
    local accountState = { mergedCharacters = "broken", separatedCharacters = 7 }
    local merges = CharacterMergeMap.Ensure(accountState)
    assert(type(merges.merged) == "table" and type(merges.separated) == "table", "broken saved values become empty tables")
  end

  -- test_record_then_get_returns_bnet_key_and_name
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K, B, "Arthas")
    local entry = CharacterMergeMap.Get(merges, K)
    assert(entry ~= nil and entry.bnetKey == B and entry.name == "Arthas", "the entry holds the Battle.net key and the stored name")
  end

  -- test_get_ignores_a_malformed_entry
  do
    local merges = fresh()
    merges.merged[K] = { name = "Arthas" }
    merges.merged[K_OTHER_REALM] = true
    assert(CharacterMergeMap.Get(merges, K) == nil, "an entry without a Battle.net key reads as unmerged")
    assert(CharacterMergeMap.Get(merges, K_OTHER_REALM) == nil, "an entry that is not a table reads as unmerged")
  end

  -- test_get_ignores_an_entry_without_a_name
  do
    local merges = fresh()
    merges.merged[K] = { bnetKey = B }
    merges.merged[K_OTHER_REALM] = { bnetKey = B, name = "" }
    assert(CharacterMergeMap.Get(merges, K) == nil, "an entry without a name reads as unmerged")
    assert(CharacterMergeMap.Get(merges, K_OTHER_REALM) == nil, "an entry with a blank name reads as unmerged")
  end

  -- test_drop_removes_only_the_merged_entry
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K, B, "Arthas")
    CharacterMergeMap.Drop(merges, K)
    assert(CharacterMergeMap.Get(merges, K) == nil, "the merge is gone")
    assert(CharacterMergeMap.IsSeparated(merges, K) == false, "dropping a merge does not separate the character")
  end

  -- test_mark_separated_drops_the_merge_and_remembers_the_character
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K, B, "Arthas")
    CharacterMergeMap.MarkSeparated(merges, K)
    assert(CharacterMergeMap.Get(merges, K) == nil, "a separated character is no longer merged")
    assert(CharacterMergeMap.IsSeparated(merges, K) == true, "a separated character is remembered")
    assert(CharacterMergeMap.IsSeparated(merges, K_OTHER_REALM) == false, "the same name on another realm is not separated")
  end

  -- test_clear_for_bnet_drops_every_entry_pointing_at_that_chat
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K, B, "Arthas")
    CharacterMergeMap.Record(merges, K_OTHER_REALM, B, "Arthas-Area52")
    CharacterMergeMap.Record(merges, "wow::WOW::jaina", B_OTHER, "Jaina")
    merges.separated["wow::WOW::thrall"] = true
    CharacterMergeMap.ClearForBnet(merges, B)
    assert(
      CharacterMergeMap.Get(merges, K) == nil and CharacterMergeMap.Get(merges, K_OTHER_REALM) == nil,
      "both characters of the removed chat unmerge"
    )
    assert(CharacterMergeMap.Get(merges, "wow::WOW::jaina").bnetKey == B_OTHER, "another friend's merge stays")
    assert(CharacterMergeMap.IsSeparated(merges, "wow::WOW::thrall") == true, "separations stay")
  end

  -- test_rewrite_bnet_key_points_entries_at_the_new_key
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K, "bnet::BN::42", "Arthas")
    CharacterMergeMap.Record(merges, "wow::WOW::jaina", B_OTHER, "Jaina")
    CharacterMergeMap.RewriteBnetKey(merges, "bnet::BN::42", B)
    local entry = CharacterMergeMap.Get(merges, K)
    assert(entry.bnetKey == B and entry.name == "Arthas", "the entry follows the rekey and keeps its name")
    assert(CharacterMergeMap.Get(merges, "wow::WOW::jaina").bnetKey == B_OTHER, "an entry for another chat is untouched")
  end

  -- test_list_for_bnet_returns_that_chats_characters_sorted_by_name
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K_OTHER_REALM, B, "Arthas-Area52")
    CharacterMergeMap.Record(merges, "wow::WOW::uther", B, "Uther")
    CharacterMergeMap.Record(merges, K, B, "Arthas")
    CharacterMergeMap.Record(merges, "wow::WOW::jaina", B_OTHER, "Jaina")
    local list = CharacterMergeMap.ListForBnet(merges, B)
    assert(#list == 3, "three characters are merged into the chat, got " .. #list)
    assert(list[1].name == "Arthas" and list[1].characterKey == K, "sorted by name, first " .. tostring(list[1].name))
    assert(list[2].name == "Arthas-Area52" and list[2].characterKey == K_OTHER_REALM, "the other realm reads differently")
    assert(list[3].name == "Uther", "last by name")
  end

  -- test_list_for_bnet_with_no_merges_is_empty
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K, B, "Arthas")
    assert(#CharacterMergeMap.ListForBnet(merges, "bnet::BN::nobody#1") == 0, "a chat with no merges lists none")
  end

  -- test_list_for_bnet_breaks_a_name_tie_by_key
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, 7, B, "Arthas")
    CharacterMergeMap.Record(merges, K, B, "Arthas")
    local list = CharacterMergeMap.ListForBnet(merges, B)
    assert(#list == 2, "both characters are listed, got " .. #list)
    assert(list[1].characterKey == 7 and list[2].characterKey == K, "same name sorts by key, first " .. tostring(list[1].characterKey))
  end
end
