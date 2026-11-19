local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local Router = require("WhisperMessenger.Core.EventRouter")
local World = require("tests.helpers.character_merge_world")

local K, B, NAME, FRIEND = World.K, World.B, World.NAME, World.FRIEND
local newRuntime, seedB, seedK, last = World.NewState, World.SeedB, World.SeedK, World.Last

local function whisper(runtime, text, lineID)
  return Router.HandleEvent(runtime, "CHAT_MSG_WHISPER", { text = text, playerName = NAME, guid = "Player-1", lineID = lineID })
end

local function test_friend_character_whisper_lands_in_b_with_no_k_row()
  local runtime = newRuntime(FRIEND)
  seedB(runtime)
  local conversation = whisper(runtime, "hi", 101)
  local merged = runtime.store.conversations[B]
  assert(conversation == merged and runtime.store.conversations[K] == nil, "a friend's character whisper must land in B with no K row")
  assert(last(merged).channel == "WOW" and last(merged).playerName == NAME, "the line is stamped as a character line")
  assert(merged.channel == "BN" and merged.unreadCount == 1, "B stays a Battle.net chat and counts the line unread")
end

local function test_merged_whisper_lands_in_b_stamped()
  local runtime = newRuntime(FRIEND)
  seedB(runtime)
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  whisper(runtime, "again", 102)
  assert(
    last(runtime.store.conversations[B]).text == "again" and last(runtime.store.conversations[B]).playerName == NAME,
    "merged: line in B, stamped"
  )
end

local function test_merged_whisper_without_match_still_lands_in_b()
  local runtime, lookups = newRuntime(nil)
  seedB(runtime)
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  whisper(runtime, "still here", 103)
  assert(runtime.store.conversations[K] == nil and #runtime.store.conversations[B].messages == 1, "the merge stands without a match")
  assert(lookups.n == 0, "a merged character is not looked up")
end

local function test_separated_whisper_stays_in_k()
  for _, info in ipairs({ FRIEND, false }) do
    local runtime = newRuntime(info or nil)
    seedB(runtime)
    CharacterMergeMap.MarkSeparated(runtime.characterMerges, K)
    whisper(runtime, "apart", 104)
    assert(runtime.store.conversations[K] ~= nil and #runtime.store.conversations[B].messages == 0, "a separated character stays in K")
  end
end

local function test_stranger_whisper_stays_in_k()
  local runtime = newRuntime(nil)
  whisper(runtime, "who are you", 105)
  assert(runtime.store.conversations[K] ~= nil and runtime.store.conversations[B] == nil, "no match: K as today")
  assert(last(runtime.store.conversations[K]).text == "who are you", "the line is stored in K")
end

local function test_stale_entry_whisper_folds_into_new_b()
  local runtime = newRuntime(FRIEND)
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  whisper(runtime, "after delete", 106)
  assert(runtime.store.conversations[B] ~= nil and runtime.store.conversations[K] == nil, "an entry without B is dropped and the merge runs again")
  assert(CharacterMergeMap.Get(runtime.characterMerges, K).bnetKey == B, "the new merge is recorded")
end

local function test_k_record_while_merged_folds_again()
  local runtime = newRuntime(nil)
  seedB(runtime)
  seedK(runtime)
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  whisper(runtime, "back from 2.1.8", 107)
  local merged = runtime.store.conversations[B]
  assert(runtime.store.conversations[K] == nil and #merged.messages == 2, "K must fold into B again, not grow beside it")
  assert(merged.messages[1].text == "earlier" and merged.messages[2].text == "back from 2.1.8", "both lines in time order")
end

local function test_fold_calls_on_character_merged_before_the_line_is_counted()
  local runtime = newRuntime(FRIEND)
  seedB(runtime)
  runtime.activeConversationKey = K
  local calls = {}
  runtime.onCharacterMerged = function(characterKey, bnetKey)
    calls[#calls + 1] = characterKey .. ">" .. bnetKey
    runtime.activeConversationKey = bnetKey
  end
  whisper(runtime, "open chat", 108)
  assert(#calls == 1 and calls[1] == K .. ">" .. B, "the fold must call onCharacterMerged once with K and B")
  assert(runtime.store.conversations[B].unreadCount == 0, "the open-chat swap happens before the line is counted")
  whisper(runtime, "no second fold", 109)
  assert(#calls == 1, "a merged character with no K record does not fold again")
end

-- The same character can arrive under another spelling of its name; the
-- line carries the name the merge recorded.
local function test_merged_whisper_uses_the_map_name()
  local runtime = newRuntime(nil)
  seedB(runtime)
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  Router.HandleEvent(runtime, "CHAT_MSG_WHISPER", { text = "lower", playerName = "arthas-area52", guid = "Player-1", lineID = 110 })
  assert(last(runtime.store.conversations[B]).playerName == NAME, "the line is stamped with the map's name")
end

local function test_whisper_into_open_b_is_not_counted_unread()
  local runtime = newRuntime(FRIEND)
  seedB(runtime)
  runtime.activeConversationKey = B
  whisper(runtime, "while you read", 111)
  assert(runtime.store.conversations[B].unreadCount == 0, "the open check runs on the redirected key")
end

return function()
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil
  test_friend_character_whisper_lands_in_b_with_no_k_row()
  test_merged_whisper_lands_in_b_stamped()
  test_merged_whisper_without_match_still_lands_in_b()
  test_separated_whisper_stays_in_k()
  test_stranger_whisper_stays_in_k()
  test_stale_entry_whisper_folds_into_new_b()
  test_k_record_while_merged_folds_again()
  test_fold_calls_on_character_merged_before_the_line_is_counted()
  test_merged_whisper_uses_the_map_name()
  test_whisper_into_open_b_is_not_counted_unread()
  _G.C_Timer = savedTimer
end
