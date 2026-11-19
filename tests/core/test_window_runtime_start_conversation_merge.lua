local StartConversation = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.StartConversation")
local Store = require("WhisperMessenger.Model.ConversationStore")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")

-- Starting a chat with a character folded into a friend's Battle.net chat.
local K = "wow::WOW::arthas-area52"
local B = "bnet::BN::jaina#1234"
local NAME = "Arthas-Area52"

local function mergedRuntime()
  local runtime = {
    localProfileId = "Player-1234",
    store = Store.New({}),
    now = function()
      return 1000
    end,
  }
  Store.EnsureConversation(runtime.store, B, { channel = "BN", battleTag = "Jaina#1234", bnetAccountID = 77 })
  runtime.characterMerges = CharacterMergeMap.Ensure({})
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  return runtime
end

-- The start function plus a reader for the key it last selected.
local function starter(runtime)
  local selected = {}
  local start = StartConversation.Create({
    runtime = runtime,
    selectConversation = function(key)
      selected.key = key
    end,
  }).startConversation
  return start, selected
end

local function countConversations(runtime)
  local count = 0
  for _ in pairs(runtime.store.conversations) do
    count = count + 1
  end
  return count
end

return function()
  -- test_full_name_of_a_merged_character_opens_the_battle_net_chat
  do
    local runtime = mergedRuntime()
    local start, selected = starter(runtime)
    start(NAME)
    assert(selected.key == B, "a merged character's full name opens B, got " .. tostring(selected.key))
  end

  -- test_full_name_of_a_merged_character_creates_no_chat
  do
    local runtime = mergedRuntime()
    local start = starter(runtime)
    start(NAME)
    assert(countConversations(runtime) == 1, "only B exists, got " .. countConversations(runtime) .. " chats")
  end

  -- test_bare_name_of_a_merged_character_opens_the_battle_net_chat
  do
    local runtime = mergedRuntime()
    local start, selected = starter(runtime)
    start("Arthas")
    assert(selected.key == B, "a merged character's bare name opens B, got " .. tostring(selected.key))
  end

  -- test_bare_name_of_a_merged_character_creates_no_chat
  do
    local runtime = mergedRuntime()
    local start = starter(runtime)
    start("Arthas")
    assert(countConversations(runtime) == 1, "no empty chat for the bare name, got " .. countConversations(runtime) .. " chats")
  end

  -- test_separated_character_opens_its_own_chat
  do
    local runtime = mergedRuntime()
    CharacterMergeMap.MarkSeparated(runtime.characterMerges, K)
    local start, selected = starter(runtime)
    start(NAME)
    assert(selected.key == K and runtime.store.conversations[K] ~= nil, "a separated character opens K, got " .. tostring(selected.key))
  end
end
