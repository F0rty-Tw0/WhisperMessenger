local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")

-- Read-only lookups through the merge map: by character key and by name.
-- None of them changes the saved map.
local K = "wow::WOW::arthas"
local K_OTHER_REALM = "wow::WOW::arthas-area52"
local B = "bnet::BN::friend#1234"
local B_OTHER = "bnet::BN::other#5678"

local function fresh()
  return CharacterMergeMap.Ensure({})
end

local function runtimeWith(conversations)
  return { characterMerges = fresh(), store = { conversations = conversations } }
end

return function()
  -- test_live_bnet_key_finds_the_merged_chat
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K, B, "Arthas")
    assert(CharacterMergeMap.LiveBnetKey(merges, { [B] = { channel = "BN" } }, K) == B, "a merged character with B finds B")
  end

  -- test_live_bnet_key_of_an_unmerged_character_is_nil
  do
    assert(CharacterMergeMap.LiveBnetKey(fresh(), { [B] = { channel = "BN" } }, K) == nil, "unmerged: nil")
  end

  -- test_live_bnet_key_ignores_a_gone_chat
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K, B, "Arthas")
    assert(CharacterMergeMap.LiveBnetKey(merges, {}, K) == nil, "B is gone: nil")
  end

  -- test_live_bnet_key_keeps_the_entry_of_a_gone_chat
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K, B, "Arthas")
    CharacterMergeMap.LiveBnetKey(merges, {}, K)
    assert(CharacterMergeMap.Get(merges, K) ~= nil, "a lookup never changes the saved map")
  end

  -- test_live_bnet_key_without_a_map_or_key_is_nil
  do
    assert(CharacterMergeMap.LiveBnetKey(nil, {}, K) == nil, "no merge map: nil")
    assert(CharacterMergeMap.LiveBnetKey(fresh(), nil, K) == nil, "no conversations: nil")
    assert(CharacterMergeMap.LiveBnetKey(fresh(), {}, nil) == nil, "no character key: nil")
  end

  -- test_bnet_key_for_name_finds_the_merged_chat
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K_OTHER_REALM, B, "Arthas-Area52")
    assert(CharacterMergeMap.BnetKeyForName(merges, { [B] = { channel = "BN" } }, "Arthas-Area52") == B, "the character's name finds B")
  end

  -- test_bnet_key_for_an_unmerged_name_is_nil
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K_OTHER_REALM, B, "Arthas-Area52")
    assert(CharacterMergeMap.BnetKeyForName(merges, { [B] = { channel = "BN" } }, "Uther") == nil, "an unmerged name finds nothing")
  end

  -- test_bnet_key_for_a_blank_or_missing_name_is_nil
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K_OTHER_REALM, B, "Arthas-Area52")
    local conversations = { [B] = { channel = "BN" } }
    assert(CharacterMergeMap.BnetKeyForName(merges, conversations, "") == nil, "a blank name finds nothing")
    assert(CharacterMergeMap.BnetKeyForName(merges, conversations, nil) == nil, "no name finds nothing")
  end

  -- test_bnet_key_for_name_ignores_a_gone_chat_and_keeps_the_entry
  do
    local merges = fresh()
    CharacterMergeMap.Record(merges, K, B, "Arthas")
    assert(CharacterMergeMap.BnetKeyForName(merges, {}, "Arthas") == nil, "B is gone: no key")
    assert(CharacterMergeMap.Get(merges, K) ~= nil, "a lookup never changes the saved map")
  end

  -- test_resolve_whisper_name_of_a_folded_character_is_the_battle_net_chat
  do
    local runtime = runtimeWith({ [B] = { channel = "BN" } })
    CharacterMergeMap.Record(runtime.characterMerges, K, B, "Arthas")
    assert(CharacterMergeMap.ResolveWhisperName(runtime, "Arthas") == B, "folded: the name resolves to B")
  end

  -- test_resolve_whisper_name_prefers_the_character_chat
  do
    local runtime = runtimeWith({ [B] = { channel = "BN" }, [K] = { channel = "WOW", displayName = "Arthas" } })
    CharacterMergeMap.Record(runtime.characterMerges, K, B, "Arthas")
    assert(CharacterMergeMap.ResolveWhisperName(runtime, "Arthas") == K, "not folded yet: the character's own chat")
  end

  -- test_resolve_whisper_name_without_a_merge_map_uses_the_name_lookup
  do
    local runtime = runtimeWith({ [B] = { channel = "BN" } })
    runtime.characterMerges = nil
    assert(CharacterMergeMap.ResolveWhisperName(runtime, "Arthas") == nil, "no merge map: nothing")
  end

  -- test_resolve_whisper_name_prefers_the_merged_chat_over_another_realm
  do
    local runtime = runtimeWith({ [B] = { channel = "BN" }, [K_OTHER_REALM] = { channel = "WOW", displayName = "Arthas-Area52" } })
    CharacterMergeMap.Record(runtime.characterMerges, K, B, "Arthas")
    local key = CharacterMergeMap.ResolveWhisperName(runtime, "Arthas")
    assert(key == B, "folded same-realm name resolves to B, not Area52, got " .. tostring(key))
  end

  -- test_resolve_whisper_name_keeps_the_unfolded_chat_beside_another_realm
  do
    local runtime = runtimeWith({
      [B] = { channel = "BN" },
      [K] = { channel = "WOW", displayName = "Arthas" },
      [K_OTHER_REALM] = { channel = "WOW", displayName = "Arthas-Area52" },
    })
    CharacterMergeMap.Record(runtime.characterMerges, K, B, "Arthas")
    local key = CharacterMergeMap.ResolveWhisperName(runtime, "Arthas")
    assert(key == K, "not folded yet: the character's own chat wins, got " .. tostring(key))
  end

  -- test_resolve_whisper_name_finds_a_folded_other_realm_character_by_bare_name
  do
    local runtime = runtimeWith({ [B] = { channel = "BN" } })
    CharacterMergeMap.Record(runtime.characterMerges, K_OTHER_REALM, B, "Arthas-Area52")
    local key = CharacterMergeMap.ResolveWhisperName(runtime, "Arthas")
    assert(key == B, "a bare name of one folded character resolves to B, got " .. tostring(key))
  end

  -- test_resolve_whisper_name_skips_a_bare_name_two_merged_characters_share
  do
    local runtime = runtimeWith({ [B] = { channel = "BN" }, [B_OTHER] = { channel = "BN" } })
    CharacterMergeMap.Record(runtime.characterMerges, K_OTHER_REALM, B, "Arthas-Area52")
    CharacterMergeMap.Record(runtime.characterMerges, "wow::WOW::arthas-stormrage", B_OTHER, "Arthas-Stormrage")
    local key = CharacterMergeMap.ResolveWhisperName(runtime, "Arthas")
    assert(key == nil, "two merged characters share the name: the name lookup decides, got " .. tostring(key))
  end

  -- test_resolve_whisper_name_keeps_a_same_realm_chat_over_a_bare_name_merge
  do
    local runtime = runtimeWith({ [B] = { channel = "BN" }, [K] = { channel = "WOW", displayName = "Arthas" } })
    CharacterMergeMap.Record(runtime.characterMerges, K_OTHER_REALM, B, "Arthas-Area52")
    local key = CharacterMergeMap.ResolveWhisperName(runtime, "Arthas")
    assert(key == K, "an unmerged chat with the same name keeps the bare name, got " .. tostring(key))
  end
end
