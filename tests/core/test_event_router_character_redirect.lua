local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local WhisperMessage = require("WhisperMessenger.Core.EventRouter.WhisperMessage")
local CharacterRedirect = require("WhisperMessenger.Core.EventRouter.CharacterRedirect")
local World = require("tests.helpers.character_merge_world")

local K, B, NAME, FRIEND = World.K, World.B, World.NAME, World.FRIEND

local function whisperPayload()
  return { playerName = NAME, guid = "Player-1", text = "hi", lineID = 1 }
end

local function resolve(state, payload)
  payload = payload or whisperPayload()
  local contact, key = WhisperMessage.BuildConversationContact(state, payload)
  return CharacterRedirect.Resolve(state, contact, key, payload)
end

-- A K record as an older session left it: a line not yet stamped.
local function seedUnstampedK(state)
  World.SeedK(state, { id = "5", kind = "user", direction = "in", text = "old", sentAt = 10 })
end

local function test_unmerged_match_redirects_to_b()
  local state = World.NewState(FRIEND)
  local key, entry = resolve(state)
  assert(key == B and entry and entry.bnetKey == B and entry.name == NAME, "a match must redirect to B, got " .. tostring(key))
end

local function test_unmerged_match_creates_b_and_no_k_row()
  local state = World.NewState(FRIEND)
  resolve(state)
  assert(state.store.conversations[B] ~= nil and state.store.conversations[K] == nil, "B exists, no K row")
end

local function test_merged_returns_b_with_the_maps_name()
  local state = World.MergedState()
  local key, entry = resolve(state)
  assert(key == B and entry.name == NAME, "a merged character goes to B")
end

local function test_merged_is_never_looked_up()
  local state, lookups = World.MergedState()
  resolve(state)
  assert(lookups.n == 0, "a merged character is never looked up")
end

local function test_separated_stays_k_without_lookup()
  local state, lookups = World.NewState(FRIEND)
  CharacterMergeMap.MarkSeparated(state.characterMerges, K)
  local key, entry = resolve(state)
  assert(key == K and entry == nil and lookups.n == 0, "a separated character stays in K with no lookup")
end

local function test_stale_entry_is_looked_up_again()
  local state, lookups = World.NewState(FRIEND)
  CharacterMergeMap.Record(state.characterMerges, K, B, NAME)
  local key = resolve(state)
  assert(lookups.n == 1 and key == B and state.store.conversations[B] ~= nil, "an entry without B is dropped and the lookup runs again")
end

local function test_stale_entry_without_a_match_is_dropped()
  local state = World.NewState(nil)
  CharacterMergeMap.Record(state.characterMerges, K, B, NAME)
  assert(resolve(state) == K and CharacterMergeMap.Get(state.characterMerges, K) == nil, "no match after the drop: K, entry gone")
end

local function test_merged_with_k_record_folds_again()
  local state = World.MergedState()
  seedUnstampedK(state)
  local key = resolve(state)
  assert(key == B and state.store.conversations[K] == nil, "a K record next to a merge folds into B again")
end

local function test_refold_moves_k_lines_into_b_stamped()
  local state = World.MergedState()
  seedUnstampedK(state)
  resolve(state)
  local merged = state.store.conversations[B]
  assert(#merged.messages == 1 and merged.messages[1].playerName == NAME, "K's line moves into B stamped")
end

local function test_battle_net_whisper_keeps_its_own_key()
  local state, lookups = World.NewState(FRIEND)
  local bnPayload = { channel = "BN", bnetAccountID = 77, accountInfo = FRIEND, playerName = "Jaina", text = "hi" }
  local key, entry = resolve(state, bnPayload)
  assert(key == B and entry == nil and lookups.n == 0, "a Battle.net whisper keeps its own key")
end

local function test_state_without_a_merge_map_passes_through()
  local state, lookups = World.NewState(FRIEND)
  state.characterMerges = nil
  assert(resolve(state) == K and lookups.n == 0, "no merge handle: today's key")
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
  local state = World.MergedState()
  local payload = whisperPayload()
  local contact = WhisperMessage.BuildConversationContact(state, payload)
  local _, entry = resolve(state, payload)
  local message = WhisperMessage.BuildMessage(state, payload, contact, "in", "user", 10)
  CharacterRedirect.Stamp(message, entry)
  assert(message.channel == "WOW", "a line routed into B still reads as a character line, got " .. tostring(message.channel))
end

return function()
  test_unmerged_match_redirects_to_b()
  test_unmerged_match_creates_b_and_no_k_row()
  test_merged_returns_b_with_the_maps_name()
  test_merged_is_never_looked_up()
  test_separated_stays_k_without_lookup()
  test_stale_entry_is_looked_up_again()
  test_stale_entry_without_a_match_is_dropped()
  test_merged_with_k_record_folds_again()
  test_refold_moves_k_lines_into_b_stamped()
  test_battle_net_whisper_keeps_its_own_key()
  test_state_without_a_merge_map_passes_through()
  test_stamp_sets_the_maps_name()
  test_stamp_without_an_entry_changes_nothing()
  test_a_merged_whisper_line_keeps_the_character_channel()
end
