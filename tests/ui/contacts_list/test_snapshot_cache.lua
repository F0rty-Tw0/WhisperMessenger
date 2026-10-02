-- Incoming-line refreshes reuse contact snapshots for conversations that did
-- not change. Enrichers write status onto the reused card in place, so a
-- reused card must come back exactly as a fresh rebuild would.

local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")
local SnapshotCache = require("WhisperMessenger.UI.ContactsList.SnapshotCache")
local ConversationSnapshot = require("WhisperMessenger.Model.ConversationSnapshot")
local ContactEnricher = require("WhisperMessenger.Model.ContactEnricher")
local LivePresence = require("WhisperMessenger.Model.LivePresence")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local Availability = require("WhisperMessenger.Transport.Availability")

local NOW = 100

local function newState()
  return {
    settings = {},
    conversations = {
      ["wow::WOW::a"] = { displayName = "A", channel = "WOW", guid = "guid-a", lastActivityAt = 6, messages = {} },
      ["wow::WOW::b"] = { displayName = "B", channel = "WOW", guid = "guid-b", lastActivityAt = 5, messages = {} },
      ["wow::WOW::c"] = { displayName = "C", channel = "WOW", guid = "guid-c", lastActivityAt = 4, messages = {} },
      ["bnet::BN::d"] = {
        displayName = "D#1",
        channel = "BN",
        guid = "guid-d",
        bnetAccountID = 7,
        battleTag = "D#1",
        lastActivityAt = 3,
        messages = {},
      },
      ["guild::me"] = { displayName = "Guild", channel = "GUILD", lastActivityAt = 2, messages = {} },
      ["party::me"] = { displayName = "Party", channel = "PARTY", lastActivityAt = 1, messages = {} },
    },
  }
end

local onlineBNet = {
  bnetAccountID = 7,
  battleTag = "D#1",
  isOnline = true,
  gameAccountInfo = {
    characterName = "Dee",
    isOnline = true,
    factionName = "Horde",
    raceName = "Orc",
    areaName = "Orgrimmar",
    className = "Mage",
    playerGuid = "guid-d",
  },
}
local offlineBNet = { bnetAccountID = 7, battleTag = "D#1", isOnline = false, lastOnlineTime = 50, gameAccountInfo = { isOnline = false } }

local function newRuntime(state)
  local runtime = {
    availabilityByGUID = {},
    sendStatusByConversation = {},
    store = { conversations = state.conversations },
    now = function()
      return NOW
    end,
    playerInfoByGUID = function()
      return "Mage", "MAGE", "Orc", "Orc"
    end,
  }
  runtime.bnetApi = {
    GetAccountInfoByID = function()
      return runtime.bnetInfo
    end,
  }
  return runtime
end

-- Refresh 1: A online and typing, D in WoW in Orgrimmar.
local function goOnline(runtime)
  runtime.availabilityByGUID["guid-a"] = Availability.FromStatus("CanWhisper")
  PresenceCache._setCache({ ["guid-a"] = "online" })
  LivePresence.SetTyping(runtime, "wow::WOW::a", true, NOW)
  runtime.bnetInfo = onlineBNet
end

-- Refresh 2: A offline and done typing, D logged off.
local function goOffline(runtime)
  runtime.availabilityByGUID["guid-a"] = nil
  PresenceCache._setCache({})
  LivePresence.SetTyping(runtime, "wow::WOW::a", false, NOW)
  runtime.bnetInfo = offlineBNet
end

local function build(state, runtime, cache, dirtyKeys)
  local items = DataBuilder.BuildItemsForProfile(state, "me", cache, dirtyKeys)
  ContactEnricher.EnrichContactsAvailability(items, runtime)
  ContactEnricher.EnrichContactsPresence(items, runtime)
  local byKey = {}
  for _, item in ipairs(items) do
    byKey[item.conversationKey] = item
  end
  return byKey
end

local function deepEqual(left, right, path)
  if left == right then
    return true
  end
  if type(left) ~= "table" or type(right) ~= "table" then
    return false, path
  end
  for key, value in pairs(left) do
    local ok, where = deepEqual(value, right[key], path .. "." .. tostring(key))
    if not ok then
      return false, where
    end
  end
  for key in pairs(right) do
    if left[key] == nil then
      return false, path .. "." .. tostring(key)
    end
  end
  return true
end

local function countBuilds(run)
  local original = ConversationSnapshot.Build
  local builds = 0
  rawset(ConversationSnapshot, "Build", function(...)
    builds = builds + 1
    return original(...)
  end)
  run()
  rawset(ConversationSnapshot, "Build", original)
  return builds
end

return function()
  PresenceCache._reset()

  -- test_incremental_build_rebuilds_only_dirty_keys
  do
    local state = newState()
    local cache = SnapshotCache.New()
    local full = countBuilds(function()
      DataBuilder.BuildItemsForProfile(state, "me", cache, nil)
    end)
    assert(full == 6, "full build must build every conversation, got " .. full)
    local incremental = countBuilds(function()
      DataBuilder.BuildItemsForProfile(state, "me", cache, { ["party::me"] = true })
    end)
    assert(incremental == 1, "only the dirty conversation may rebuild, got " .. incremental)
  end

  -- test_reused_card_carries_no_stale_enrichment
  do
    local state = newState()
    local runtime = newRuntime(state)
    local cache = SnapshotCache.New()
    goOnline(runtime)
    local first = build(state, runtime, cache, nil)
    assert(first["wow::WOW::a"].availability.status == "CanWhisper", "refresh 1 shows A online")
    assert(first["wow::WOW::a"].isTyping == true, "refresh 1 shows A typing")
    assert(first["bnet::BN::d"].areaName == "Orgrimmar", "refresh 1 shows D's zone")

    goOffline(runtime)
    local second = build(state, runtime, cache, {})
    local a, d = second["wow::WOW::a"], second["bnet::BN::d"]
    assert(a == first["wow::WOW::a"], "an unchanged conversation reuses its card")
    assert(a.availability.status == "Offline", "reused card must show A offline, got " .. tostring(a.availability.status))
    assert(a.isTyping ~= true, "reused card must not keep A typing")
    assert(d.areaName == nil, "reused card must not keep D's old zone, got " .. tostring(d.areaName))
    assert(d.factionName == nil, "reused card must not keep D's old faction")
    assert(d.availability.status == "Offline", "reused card must show D offline")
  end

  -- test_incremental_build_equals_full_rebuild_after_enrichment
  do
    local state = newState()
    local runtime = newRuntime(state)
    local cache = SnapshotCache.New()
    goOffline(runtime)
    build(state, runtime, cache, nil)
    goOnline(runtime)
    local incremental = build(state, runtime, cache, {})
    local full = build(state, runtime, SnapshotCache.New(), nil)
    for key, item in pairs(full) do
      local ok, where = deepEqual(incremental[key], item, key)
      assert(ok, "incremental card differs from a full rebuild at " .. tostring(where))
    end
  end

  -- test_swapped_conversation_table_forces_rebuild
  do
    local state = newState()
    local cache = SnapshotCache.New()
    DataBuilder.BuildItemsForProfile(state, "me", cache, nil)
    local swapped = { displayName = "B2", channel = "WOW", guid = "guid-b", lastActivityAt = 5, messages = {} }
    state.conversations["wow::WOW::b"] = swapped
    local items
    local builds = countBuilds(function()
      items = DataBuilder.BuildItemsForProfile(state, "me", cache, {})
    end)
    assert(builds == 1, "a conversation swapped under its key must rebuild, got " .. builds)
    local found
    for _, item in ipairs(items) do
      if item.conversationKey == "wow::WOW::b" then
        found = item
      end
    end
    assert(found.conversation == swapped and found.displayName == "B2", "rebuilt card must read the new conversation")
  end

  -- test_removed_conversation_leaves_the_cache
  do
    local state = newState()
    local cache = SnapshotCache.New()
    DataBuilder.BuildItemsForProfile(state, "me", cache, nil)
    state.conversations["wow::WOW::c"] = nil
    DataBuilder.BuildItemsForProfile(state, "me", cache, {})
    assert(cache["wow::WOW::c"] == nil, "a removed conversation must be pruned from the cache")
  end
end
