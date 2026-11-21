local Store = require("WhisperMessenger.Model.ConversationStore")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local Router = require("WhisperMessenger.Core.EventRouter")
local World = require("tests.helpers.character_merge_world")

local K, B, NAME, FRIEND = World.K, World.B, World.NAME, World.FRIEND
local newRuntime, seedB, last = World.NewState, World.SeedB, World.Last

local function route(runtime, eventName, payload)
  payload.playerName = payload.playerName or NAME
  return Router.HandleEvent(runtime, eventName, payload)
end

local function test_inform_with_recipient_guid_merges()
  local runtime = newRuntime(FRIEND)
  seedB(runtime)
  route(runtime, "CHAT_MSG_WHISPER_INFORM", { text = "hello", guid = "Player-1", lineID = 201 })
  assert(runtime.store.conversations[K] == nil, "an echo with the recipient GUID merges K into B")
  local sent = last(runtime.store.conversations[B])
  assert(sent.direction == "out" and sent.channel == "WOW" and sent.playerName == NAME, "the sent line in B keeps channel and name (Compact rule)")
  assert(runtime.store.conversations[B].channel == "BN", "replies from B still go over Battle.net")
end

local function test_inform_without_recipient_guid_stays_in_k()
  local runtime, lookups = newRuntime(FRIEND)
  seedB(runtime)
  route(runtime, "CHAT_MSG_WHISPER_INFORM", { text = "hello", lineID = 202 })
  assert(runtime.store.conversations[K] ~= nil and lookups.n == 0, "no recipient GUID: no lookup, K as today")
end

local function test_merged_inform_lands_in_b_stamped()
  local runtime = newRuntime(nil)
  seedB(runtime)
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  route(runtime, "CHAT_MSG_WHISPER_INFORM", { text = "merged hello", lineID = 203 })
  local sent = last(runtime.store.conversations[B])
  assert(sent.direction == "out" and sent.playerName == NAME, "merged echo lands in B stamped")
end

local function test_merged_inform_uses_the_map_name()
  local runtime = newRuntime(nil)
  seedB(runtime)
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  route(runtime, "CHAT_MSG_WHISPER_INFORM", { text = "lower", playerName = "arthas-area52", lineID = 212 })
  assert(last(runtime.store.conversations[B]).playerName == NAME, "the sent line is stamped with the map's name")
end

local function test_separated_inform_stays_in_k()
  local runtime, lookups = newRuntime(FRIEND)
  seedB(runtime)
  CharacterMergeMap.MarkSeparated(runtime.characterMerges, K)
  route(runtime, "CHAT_MSG_WHISPER_INFORM", { text = "apart", guid = "Player-1", lineID = 204 })
  assert(runtime.store.conversations[K] ~= nil and lookups.n == 0, "separated echo stays in K")
end

local function test_afk_from_friend_character_sets_status_on_b()
  local runtime = newRuntime(FRIEND)
  seedB(runtime)
  route(runtime, "CHAT_MSG_AFK", { text = "away", guid = "Player-1", lineID = 205 })
  local merged = runtime.store.conversations[B]
  assert(merged.activeStatus.eventName == "CHAT_MSG_AFK" and runtime.store.conversations[K] == nil, "AFK from a friend's character lands on B")
  route(runtime, "CHAT_MSG_DND", { text = "busy", guid = "Player-1", lineID = 206 })
  assert(merged.activeStatus.eventName == "CHAT_MSG_DND", "DND while merged lands on B")
end

local function test_separated_afk_stays_on_k()
  local runtime = newRuntime(FRIEND)
  seedB(runtime)
  CharacterMergeMap.MarkSeparated(runtime.characterMerges, K)
  route(runtime, "CHAT_MSG_AFK", { text = "away", guid = "Player-1", lineID = 207 })
  local characterChat = runtime.store.conversations[K]
  assert(characterChat and characterChat.activeStatus ~= nil and runtime.store.conversations[B].activeStatus == nil, "separated AFK stays on K")
end

local function test_replayed_friend_whisper_merges_like_live()
  local runtime = newRuntime(FRIEND)
  seedB(runtime)
  route(runtime, "CHAT_MSG_WHISPER", { text = "held", guid = "Player-1", lineID = 208, replayedAt = 900 })
  assert(runtime.store.conversations[K] == nil and last(runtime.store.conversations[B]).sentAt == 900, "a held whisper merges like a live one")
end

local function test_replayed_merged_whisper_lands_in_b_in_time_order()
  local runtime = newRuntime(nil)
  local merged = seedB(runtime)
  Store.AppendIncoming(runtime.store, B, { id = "950", kind = "user", direction = "in", text = "newer", sentAt = 950, channel = "BN" }, false)
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  route(runtime, "CHAT_MSG_WHISPER", { text = "held", guid = "Player-1", lineID = 209, replayedAt = 900 })
  assert(merged.messages[1].sentAt == 900 and merged.messages[1].playerName == NAME, "the held line lands before the newer one, stamped")
end

local function test_separated_replay_stays_in_k()
  local runtime = newRuntime(FRIEND)
  seedB(runtime)
  CharacterMergeMap.MarkSeparated(runtime.characterMerges, K)
  route(runtime, "CHAT_MSG_WHISPER", { text = "held apart", guid = "Player-1", lineID = 210, replayedAt = 900 })
  assert(runtime.store.conversations[K] ~= nil and #runtime.store.conversations[B].messages == 0, "separated replay stays in K")
end

local function test_bn_offline_line_for_merged_friend_lands_in_b()
  local runtime = newRuntime(FRIEND)
  seedB(runtime)
  CharacterMergeMap.Record(runtime.characterMerges, K, B, NAME)
  local payload = { text = "Player is offline", channel = "BN", bnetAccountID = 77, accountInfo = FRIEND, lineID = 211 }
  route(runtime, "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE", payload)
  assert(last(runtime.store.conversations[B]).kind == "system" and runtime.store.conversations[K] == nil, "the offline line lands in B")
end

return function()
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil
  test_inform_with_recipient_guid_merges()
  test_inform_without_recipient_guid_stays_in_k()
  test_merged_inform_lands_in_b_stamped()
  test_merged_inform_uses_the_map_name()
  test_separated_inform_stays_in_k()
  test_afk_from_friend_character_sets_status_on_b()
  test_separated_afk_stays_on_k()
  test_replayed_friend_whisper_merges_like_live()
  test_replayed_merged_whisper_lands_in_b_in_time_order()
  test_separated_replay_stays_in_k()
  test_bn_offline_line_for_merged_friend_lands_in_b()
  _G.C_Timer = savedTimer
end
