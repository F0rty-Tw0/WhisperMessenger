local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local Identity = require("WhisperMessenger.Model.Identity")
local ConversationOps = require("WhisperMessenger.Core.Bootstrap.AutoOpenCoordinator.ConversationOps")
local World = require("tests.helpers.character_merge_world")

local function test_merged_name_builds_the_battle_net_key()
  local runtime = World.MergedState()
  local key = ConversationOps.buildConversationKeyFromName(runtime, Identity, World.NAME)
  assert(key == World.B, "a /w to a merged character opens B, got " .. tostring(key))
end

local function test_ensure_keeps_b_a_battle_net_chat()
  local runtime = World.MergedState()
  ConversationOps.ensureConversation(runtime, World.B, World.NAME)
  assert(runtime.store.conversations[World.B].channel == "BN", "ensure leaves B a Battle.net chat")
end

local function test_ensure_on_b_creates_no_character_chat()
  local runtime = World.MergedState()
  ConversationOps.ensureConversation(runtime, World.B, World.NAME)
  assert(runtime.store.conversations[World.K] == nil, "ensure on B creates no K row")
end

local function test_unmerged_name_builds_the_character_key()
  local runtime = World.MergedState()
  runtime.characterMerges = CharacterMergeMap.Ensure({})
  local key = ConversationOps.buildConversationKeyFromName(runtime, Identity, World.NAME)
  assert(key == World.K, "unmerged: K as today, got " .. tostring(key))
end

-- AutoOpenHooks marks this key read when the player replies in the game's chat.
local function test_merged_name_finds_the_battle_net_chat()
  local runtime = World.MergedState()
  assert(ConversationOps.findConversationKeyByName(runtime, World.NAME) == World.B, "a merged character's name finds B")
end

return function()
  test_merged_name_finds_the_battle_net_chat()
  test_merged_name_builds_the_battle_net_key()
  test_ensure_keeps_b_a_battle_net_chat()
  test_ensure_on_b_creates_no_character_chat()
  test_unmerged_name_builds_the_character_key()
end
