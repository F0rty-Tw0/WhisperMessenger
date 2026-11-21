local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")
local Store = require("WhisperMessenger.Model.ConversationStore")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")

-- The window's Separate callbacks: list a Battle.net chat's characters for
-- the menu, split one out and redraw.
local K = "wow::WOW::arthas"
local B = "bnet::BN::jaina#1234"

local function newRuntime()
  local store = Store.New({ maxMessagesPerConversation = 50, maxConversations = 10 })
  store.conversations[B] = {
    conversationKey = B,
    channel = "BN",
    displayName = "Jaina#1234",
    unreadCount = 0,
    unreadActivityCount = 0,
    lastActivityAt = 200,
    messages = { { id = "20", lineID = 20, kind = "user", direction = "in", text = "k", sentAt = 200, channel = "WOW", playerName = "Arthas" } },
  }
  local merges = CharacterMergeMap.Ensure({})
  CharacterMergeMap.Record(merges, K, B, "Arthas")
  return { store = store, characterMerges = merges, activeConversationKey = B }
end

local function create(runtime, refreshes)
  return WindowCallbacks.Create({
    runtime = runtime,
    accountState = {},
    characterState = {},
    refreshWindow = function(...)
      refreshes[#refreshes + 1] = select("#", ...)
    end,
  })
end

return function()
  -- test_list_merged_characters_reads_the_map
  do
    local callbacks = create(newRuntime(), {})
    assert(type(callbacks.listMergedCharacters) == "function", "the window offers the merged characters to the menu")
    local list = callbacks.listMergedCharacters(B)
    assert(#list == 1 and list[1].characterKey == K and list[1].name == "Arthas", "the chat's one merged character")
  end

  -- test_separate_character_splits_and_redraws_everything
  do
    local runtime = newRuntime()
    local refreshes = {}
    local callbacks = create(runtime, refreshes)
    assert(type(callbacks.onSeparateCharacter) == "function", "the window has a Separate callback")
    callbacks.onSeparateCharacter(B, K)
    assert(runtime.store.conversations[K] ~= nil, "the character's chat is back")
    assert(#refreshes == 1 and refreshes[1] == 0, "one full refresh, so the new row shows")
    assert(runtime.activeConversationKey == B, "the open chat stays open")
  end

  -- test_without_a_merge_map_nothing_happens
  do
    local refreshes = {}
    local callbacks = create({ store = Store.New({}) }, refreshes)
    assert(#callbacks.listMergedCharacters(B) == 0, "no map: no characters")
    callbacks.onSeparateCharacter(B, K)
    assert(#refreshes == 0, "no map: no refresh")
  end
end
