local Store = require("WhisperMessenger.Model.ConversationStore")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local WhisperMessage = require("WhisperMessenger.Core.EventRouter.WhisperMessage")
local CharacterRedirect = require("WhisperMessenger.Core.EventRouter.CharacterRedirect")

local K = "wow::WOW::arthas-area52"
local B = "bnet::BN::jaina#1234"
local NAME = "Arthas-Area52"
local FRIEND = { bnetAccountID = 77, battleTag = "Jaina#1234" }

local function newState(accountInfo)
  local lookups = { n = 0 }
  local state = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 50 }),
    characterMerges = CharacterMergeMap.Ensure({}),
    bnetApi = {
      GetAccountInfoByGUID = function()
        lookups.n = lookups.n + 1
        return accountInfo
      end,
    },
  }
  return state, lookups
end

local function seedB(state)
  Store.EnsureConversation(state.store, B, { channel = "BN", displayName = "Jaina#1234", battleTag = "Jaina#1234", bnetAccountID = 77 })
end

local function seedK(state)
  state.store.conversations[K] = {
    conversationKey = K,
    channel = "WOW",
    displayName = NAME,
    unreadCount = 0,
    unreadActivityCount = 0,
    lastActivityAt = 10,
    messages = { { id = "5", kind = "user", direction = "in", text = "old", sentAt = 10 } },
  }
end

local function resolve(state, payload)
  payload = payload or { playerName = NAME, guid = "Player-1", text = "hi", lineID = 1 }
  local contact, key = WhisperMessage.BuildConversationContact(state, payload)
  return CharacterRedirect.Resolve(state, contact, key, payload)
end

local function test_unmerged_match_folds_and_returns_b()
  local state = newState(FRIEND)
  local key, entry = resolve(state)
  assert(key == B and entry and entry.bnetKey == B and entry.name == NAME, "a match must redirect to B, got " .. tostring(key))
  assert(state.store.conversations[B] ~= nil and state.store.conversations[K] == nil, "B exists, no K row")
end

local function test_merged_returns_b_without_lookup()
  local state, lookups = newState(nil)
  seedB(state)
  CharacterMergeMap.Record(state.characterMerges, K, B, NAME)
  local key, entry = resolve(state)
  assert(key == B and entry.name == NAME, "a merged character goes to B")
  assert(lookups.n == 0, "a merged character is never looked up")
end

local function test_separated_stays_k_without_lookup()
  local state, lookups = newState(FRIEND)
  CharacterMergeMap.MarkSeparated(state.characterMerges, K)
  local key, entry = resolve(state)
  assert(key == K and entry == nil and lookups.n == 0, "a separated character stays in K with no lookup")
end

local function test_stale_entry_is_dropped_and_looked_up_again()
  local state, lookups = newState(FRIEND)
  CharacterMergeMap.Record(state.characterMerges, K, B, NAME)
  local key = resolve(state)
  assert(lookups.n == 1 and key == B and state.store.conversations[B] ~= nil, "an entry without B is dropped and the lookup runs again")
  local strangerState = newState(nil)
  CharacterMergeMap.Record(strangerState.characterMerges, K, B, NAME)
  assert(resolve(strangerState) == K and CharacterMergeMap.Get(strangerState.characterMerges, K) == nil, "no match after the drop: K, entry gone")
end

local function test_merged_with_k_record_folds_again()
  local state = newState(nil)
  seedB(state)
  seedK(state)
  CharacterMergeMap.Record(state.characterMerges, K, B, NAME)
  local key = resolve(state)
  local merged = state.store.conversations[B]
  assert(key == B and state.store.conversations[K] == nil, "a K record next to a merge folds into B again")
  assert(#merged.messages == 1 and merged.messages[1].playerName == NAME, "K's line moves into B stamped")
end

local function test_battle_net_and_unwired_states_pass_through()
  local state, lookups = newState(FRIEND)
  local bnPayload = { channel = "BN", bnetAccountID = 77, accountInfo = FRIEND, playerName = "Jaina", text = "hi" }
  local bnKey, bnEntry = resolve(state, bnPayload)
  assert(bnKey == B and bnEntry == nil and lookups.n == 0, "a Battle.net whisper keeps its own key")
  state.characterMerges = nil
  assert(resolve(state) == K and lookups.n == 0, "no merge handle: today's key")
end

local function test_merged_key_reads_the_map_only()
  local state, lookups = newState(FRIEND)
  assert(CharacterRedirect.MergedKey(state, K) == nil, "unmerged: nil")
  CharacterMergeMap.Record(state.characterMerges, K, B, NAME)
  assert(CharacterRedirect.MergedKey(state, K) == nil and CharacterMergeMap.Get(state.characterMerges, K) == nil, "no B record: nil, entry dropped")
  seedB(state)
  CharacterMergeMap.Record(state.characterMerges, K, B, NAME)
  assert(CharacterRedirect.MergedKey(state, K) == B, "merged with B: B")
  assert(lookups.n == 0, "MergedKey never looks up")
  assert(CharacterRedirect.MergedKey({ localProfileId = "me" }, K) == nil, "a bare state is nil-safe")
end

local function test_stamp_sets_the_maps_name()
  local message = { channel = "WOW", playerName = "Arthas", text = "hi" }
  CharacterRedirect.Stamp(message, { bnetKey = B, name = NAME })
  assert(message.playerName == NAME, "stamp sets the map's name, got " .. tostring(message.playerName))
end

local function test_stamp_without_an_entry_changes_nothing()
  local message = { channel = "BN", playerName = "Jaina" }
  CharacterRedirect.Stamp(message, nil)
  assert(message.channel == "BN" and message.playerName == "Jaina", "no entry: no change")
end

local function test_a_merged_whisper_line_keeps_the_character_channel()
  local state = newState(nil)
  seedB(state)
  CharacterMergeMap.Record(state.characterMerges, K, B, NAME)
  local payload = { playerName = NAME, guid = "Player-1", text = "hi", lineID = 1 }
  local contact = WhisperMessage.BuildConversationContact(state, payload)
  local _, entry = resolve(state, payload)
  local message = WhisperMessage.BuildMessage(state, payload, contact, "in", "user", 10)
  CharacterRedirect.Stamp(message, entry)
  assert(message.channel == "WOW", "a line routed into B still reads as a character line, got " .. tostring(message.channel))
end

return function()
  test_unmerged_match_folds_and_returns_b()
  test_merged_returns_b_without_lookup()
  test_separated_stays_k_without_lookup()
  test_stale_entry_is_dropped_and_looked_up_again()
  test_merged_with_k_record_folds_again()
  test_battle_net_and_unwired_states_pass_through()
  test_merged_key_reads_the_map_only()
  test_stamp_sets_the_maps_name()
  test_stamp_without_an_entry_changes_nothing()
  test_a_merged_whisper_line_keeps_the_character_channel()
end
