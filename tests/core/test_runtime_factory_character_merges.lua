local RuntimeFactory = require("WhisperMessenger.Core.Bootstrap.RuntimeFactory")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local Store = require("WhisperMessenger.Model.ConversationStore")
local StoreRetention = require("WhisperMessenger.Model.ConversationStore.StoreRetention")

-- The runtime holds the saved merge maps. A Battle.net chat that leaves the
-- store, by any route, takes its character merges with it, so a later
-- whisper from the character can merge into a new chat.
local B = "bnet::BN::friend#1234"
local B_OTHER = "bnet::BN::other#5678"
local K = "wow::WOW::arthas"

local function build(accountState)
  local runtime = RuntimeFactory.CreateRuntimeState(accountState, {}, "me", {
    now = function()
      return 1000
    end,
  })
  Store.EnsureConversation(runtime.store, B)
  Store.EnsureConversation(runtime.store, B_OTHER)
  CharacterMergeMap.Record(runtime.characterMerges, K, B, "Arthas")
  CharacterMergeMap.Record(runtime.characterMerges, "wow::WOW::jaina", B_OTHER, "Jaina")
  CharacterMergeMap.MarkSeparated(runtime.characterMerges, "wow::WOW::thrall")
  return runtime
end

return function()
  -- test_runtime_merges_are_the_saved_tables
  do
    local accountState = { conversations = {} }
    local runtime = build(accountState)
    assert(runtime.characterMerges.merged == accountState.mergedCharacters, "merges write to the saved table")
    assert(runtime.characterMerges.separated == accountState.separatedCharacters, "separations write to the saved table")
  end

  -- test_removing_battle_net_chat_clears_its_merges_for_every_reason
  for _, reason in ipairs({ StoreRetention.REASON_EXPLICIT, StoreRetention.REASON_RETENTION, StoreRetention.REASON_CAPACITY }) do
    local runtime = build({ conversations = {} })
    StoreRetention.Remove(runtime.store, B, reason)
    assert(CharacterMergeMap.Get(runtime.characterMerges, K) == nil, reason .. ": the removed chat's character unmerges")
    assert(CharacterMergeMap.Get(runtime.characterMerges, "wow::WOW::jaina").bnetKey == B_OTHER, reason .. ": another chat keeps its merge")
    assert(CharacterMergeMap.IsSeparated(runtime.characterMerges, "wow::WOW::thrall"), reason .. ": separations stay")
  end

  -- test_clear_all_clears_every_merge
  do
    local runtime = build({ conversations = {} })
    Store.RemoveAll(runtime.store)
    assert(next(runtime.characterMerges.merged) == nil, "no merge outlives Clear all")
  end
end
