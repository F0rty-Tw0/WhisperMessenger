local Store = require("WhisperMessenger.Model.ConversationStore")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local Identity = require("WhisperMessenger.Model.Identity")
local ConversationOps = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.ConversationOps")

local K = "wow::WOW::arthas-area52"
local B = "bnet::BN::jaina#1234"
local NAME = "Arthas-Area52"

local function mergedRuntime()
  local runtime = {
    localProfileId = "me",
    store = Store.New({}),
    characterMerges = CharacterMergeMap.Ensure({}),
    now = function()
      return 100
    end,
  }
  Store.EnsureConversation(runtime.store, B, { channel = "BN", battleTag = "Jaina#1234", bnetAccountID = 77 })
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  return runtime
end

local function test_merged_name_builds_the_battle_net_key()
  local runtime = mergedRuntime()
  assert(ConversationOps.buildConversationKeyFromName(runtime, Identity, NAME) == B, "a /w to a merged character opens B")
  ConversationOps.ensureConversation(runtime, B, NAME)
  assert(runtime.store.conversations[B].channel == "BN" and runtime.store.conversations[K] == nil, "ensure leaves B a Battle.net chat, no K row")
end

local function test_unmerged_name_builds_the_character_key()
  local runtime = mergedRuntime()
  runtime.characterMerges = CharacterMergeMap.Ensure({})
  assert(ConversationOps.buildConversationKeyFromName(runtime, Identity, NAME) == K, "unmerged: K as today")
end

-- AutoOpenHooks marks this key read when the player replies in the game's chat.
local function test_merged_name_finds_the_battle_net_chat()
  local runtime = mergedRuntime()
  assert(ConversationOps.findConversationKeyByName(runtime, NAME) == B, "a merged character's name finds B")
end

return function()
  test_merged_name_finds_the_battle_net_chat()
  test_merged_name_builds_the_battle_net_key()
  test_unmerged_name_builds_the_character_key()
end
