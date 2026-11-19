local BNetRekey = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.BNetRekey")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")

-- A Battle.net chat that moves to a new key keeps the characters merged
-- into it.
return function()
  -- test_apply_mappings_points_character_merges_at_the_new_key
  do
    local merges = CharacterMergeMap.Ensure({})
    CharacterMergeMap.Record(merges, "wow::WOW::arthas", "bnet::BN::42", "Arthas")
    CharacterMergeMap.Record(merges, "wow::WOW::jaina", "bnet::BN::other#5678", "Jaina")
    BNetRekey.ApplyMappings({ characterMerges = merges }, { ["bnet::BN::42"] = "bnet::BN::friend#1234" })
    assert(CharacterMergeMap.Get(merges, "wow::WOW::arthas").bnetKey == "bnet::BN::friend#1234", "the merge follows the rekey")
    assert(CharacterMergeMap.Get(merges, "wow::WOW::jaina").bnetKey == "bnet::BN::other#5678", "an unmapped chat's merge is untouched")
  end

  -- test_apply_mappings_also_moves_the_active_chat
  do
    local runtime = { activeConversationKey = "bnet::BN::42", characterMerges = CharacterMergeMap.Ensure({}) }
    BNetRekey.ApplyMappings(runtime, { ["bnet::BN::42"] = "bnet::BN::friend#1234" })
    assert(runtime.activeConversationKey == "bnet::BN::friend#1234", "the other mappings still apply")
  end
end
