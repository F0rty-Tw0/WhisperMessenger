local StartConversation = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.StartConversation")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local World = require("tests.helpers.character_merge_world")

-- Starting a chat with a character folded into a friend's Battle.net chat.
local K, B, NAME = World.K, World.B, World.NAME
local mergedRuntime = World.MergedState

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
