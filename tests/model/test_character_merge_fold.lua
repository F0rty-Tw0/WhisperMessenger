local Store = require("WhisperMessenger.Model.ConversationStore")
local Identity = require("WhisperMessenger.Model.Identity")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local CharacterMergeFold = require("WhisperMessenger.Model.CharacterMergeFold")

local World = require("tests.helpers.character_merge_world")

local K, B, NAME = World.K, World.B, World.NAME

local function friend()
  return Identity.FromBattleNet(77, { battleTag = "Jaina#1234", accountName = "Jaina" })
end

-- A character chat as stored today: a #218-compacted sent line, a status
-- line with an older name form, an incoming line without its class.
local function characterChat()
  return {
    conversationKey = K,
    channel = "WOW",
    displayName = NAME,
    guid = "Player-1",
    classTag = "PALADIN",
    unreadCount = 1,
    unreadActivityCount = 0,
    lastActivityAt = 300,
    lastActivityLineID = 30,
    lastPreview = "k in",
    lastIncomingAt = 300,
    lastIncomingLineID = 30,
    lastIncomingSender = NAME,
    lastIncomingPreview = "k in",
    messages = {
      { id = "10", lineID = 10, kind = "user", direction = "out", text = "k out", sentAt = 100 },
      { id = "20", lineID = 20, kind = "system", direction = "in", text = "away", sentAt = 200, playerName = "Arthas" },
      { id = "30", lineID = 30, kind = "user", direction = "in", text = "k in", sentAt = 300, channel = "WOW", playerName = NAME },
    },
  }
end

local function setup(maxConversations)
  local store = Store.New({ maxMessagesPerConversation = 200, maxConversations = maxConversations })
  store.conversations[K] = characterChat()
  return store, CharacterMergeMap.Ensure({})
end

local function count(conversations)
  local n = 0
  for _ in pairs(conversations) do
    n = n + 1
  end
  return n
end

local function test_fold_without_b_moves_k_into_a_new_b_and_keeps_the_count()
  local store, merges = setup(1)
  local merged = CharacterMergeFold.Fold(store, merges, K, B, friend(), NAME, 200)
  assert(store.conversations[K] == nil, "K must be gone after the fold")
  assert(merged == store.conversations[B] and #merged.messages == 3, "B must hold all of K's lines")
  assert(merged.channel == "BN" and merged.battleTag == "Jaina#1234" and merged.bnetAccountID == 77, "B must carry the friend's identity")
  assert(count(store.conversations) == 1, "creating B must not evict K first")
end

local function test_fold_takes_k_activity_over_b_created_at_zero()
  local store, merges = setup()
  local merged = CharacterMergeFold.Fold(store, merges, K, B, friend(), NAME, 200)
  assert(merged.lastActivityAt == 300 and merged.lastPreview == "k in", "B must end with K's newer activity, got " .. tostring(merged.lastActivityAt))
end

local function test_fold_stamps_every_k_line_with_channel_and_name()
  local store, merges = setup()
  local merged = CharacterMergeFold.Fold(store, merges, K, B, friend(), NAME, 200)
  for _, line in ipairs(merged.messages) do
    assert(line.channel == "WOW" and line.playerName == NAME, "line " .. line.id .. " must be stamped as a character line")
  end
end

local function test_fold_gives_k_class_to_incoming_lines_only()
  local store, merges = setup()
  local merged = CharacterMergeFold.Fold(store, merges, K, B, friend(), NAME, 200)
  assert(merged.messages[3].classTag == "PALADIN", "incoming line without a class gets K's")
  assert(merged.messages[1].classTag == nil, "a sent line gets no class")
end

local function test_fold_into_existing_b_merges_by_time_and_keeps_b_identity()
  local store, merges = setup()
  store.conversations[B] = {
    conversationKey = B,
    channel = "BN",
    displayName = "Jaina#1234",
    battleTag = "Jaina#1234",
    bnetAccountID = 77,
    guid = "Player-B",
    unreadCount = 1,
    unreadActivityCount = 0,
    lastActivityAt = 250,
    messages = {
      { id = "15", kind = "user", direction = "in", text = "b in", sentAt = 150, channel = "BN" },
      { id = "25", kind = "user", direction = "out", text = "b out", sentAt = 250 },
    },
  }
  local merged = CharacterMergeFold.Fold(store, merges, K, B, nil, NAME, 200)
  local times = {}
  for index, line in ipairs(merged.messages) do
    times[index] = line.sentAt
  end
  assert(table.concat(times, ",") == "100,150,200,250,300", "lines must be in time order, got " .. table.concat(times, ","))
  assert(merged.unreadCount == 2, "unread from both chats is kept, got " .. tostring(merged.unreadCount))
  assert(merged.channel == "BN" and merged.guid == "Player-B" and merged.displayName == "Jaina#1234", "B keeps its identity")
end

local function test_fold_records_the_map_entry()
  local store, merges = setup()
  CharacterMergeFold.Fold(store, merges, K, B, friend(), NAME, 200)
  local entry = CharacterMergeMap.Get(merges, K)
  assert(entry and entry.bnetKey == B and entry.name == NAME, "the fold must record K -> B with K's name")
end

local function test_fold_without_k_record_ensures_b()
  local store = Store.New({ maxMessagesPerConversation = 200 })
  local merges = CharacterMergeMap.Ensure({})
  local merged = CharacterMergeFold.Fold(store, merges, K, B, friend(), NAME, 200)
  assert(merged and merged.channel == "BN" and #merged.messages == 0, "a first whisper still gets a Battle.net chat")
  assert(store.conversations[K] == nil and CharacterMergeMap.Get(merges, K).bnetKey == B, "no K row; the map entry is recorded")
end

local function test_fold_without_b_or_contact_changes_nothing()
  local store, merges = setup()
  assert(CharacterMergeFold.Fold(store, merges, K, B, nil, NAME, 200) == nil, "no contact and no B: nothing to fold into")
  assert(store.conversations[K] ~= nil and CharacterMergeMap.Get(merges, K) == nil, "K and the map stay as they were")
end

return function()
  test_fold_without_b_moves_k_into_a_new_b_and_keeps_the_count()
  test_fold_takes_k_activity_over_b_created_at_zero()
  test_fold_stamps_every_k_line_with_channel_and_name()
  test_fold_gives_k_class_to_incoming_lines_only()
  test_fold_into_existing_b_merges_by_time_and_keeps_b_identity()
  test_fold_records_the_map_entry()
  test_fold_without_k_record_ensures_b()
  test_fold_without_b_or_contact_changes_nothing()
end
