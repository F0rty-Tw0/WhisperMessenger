-- Whisper refreshes rebuild only the whispered contacts. The append that
-- stores a whisper can also run the retention sweep over every other chat,
-- so a keyed rebuild must still drop the chats the sweep removed.

local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")
local SnapshotCache = require("WhisperMessenger.UI.ContactsList.SnapshotCache")
local Store = require("WhisperMessenger.Model.ConversationStore")
local PerfCounters = require("WhisperMessenger.Util.PerfCounters")

local DAY = 86400
local NOW = 100 * DAY

local KEY_A = "wow::WOW::a"
local KEY_B = "wow::WOW::b"
local KEY_C = "wow::WOW::c"

local function newStore()
  local store = Store.New({ conversationMaxAge = 30 * DAY }, function()
    return NOW
  end)
  store.settings = {}
  store.conversations[KEY_A] = { displayName = "A", channel = "WOW", lastActivityAt = NOW - 10, unreadCount = 0, messages = {} }
  store.conversations[KEY_B] = { displayName = "B", channel = "WOW", lastActivityAt = NOW - 60 * DAY, unreadCount = 0, messages = {} }
  store.conversations[KEY_C] = { displayName = "C", channel = "WOW", lastActivityAt = NOW - 20, unreadCount = 0, messages = {} }
  return store
end

local function byKey(items)
  local found = {}
  for _, item in ipairs(items) do
    found[item.conversationKey] = item
  end
  return found
end

return function()
  -- test_dirty_whisper_refresh_rebuilds_one_snapshot
  do
    local store = newStore()
    local cache = SnapshotCache.New()
    DataBuilder.BuildItemsForProfile(store, "me", cache, nil)
    PerfCounters.Reset()
    DataBuilder.BuildItemsForProfile(store, "me", cache, { [KEY_A] = true })
    assert(PerfCounters.Get("snapshotBuilds") == 1, "one whispered key rebuilds one snapshot, got " .. PerfCounters.Get("snapshotBuilds"))
  end

  -- test_dirty_refresh_after_retention_sweep_drops_removed_chat
  do
    local store = newStore()
    local cache = SnapshotCache.New()
    DataBuilder.BuildItemsForProfile(store, "me", cache, nil)

    Store.AppendIncoming(store, KEY_A, { id = "m1", direction = "in", kind = "user", text = "hello there", sentAt = NOW }, false)
    assert(store.conversations[KEY_B] == nil, "the append's retention sweep removes the expired chat")

    local found = byKey(DataBuilder.BuildItemsForProfile(store, "me", cache, { [KEY_A] = true }))
    assert(found[KEY_B] == nil, "the removed chat must leave the contact list")
    assert(cache[KEY_B] == nil, "the removed chat must leave the snapshot cache")
    assert(found[KEY_A].lastPreview == "hello there", "the whispered card shows the new preview, got " .. tostring(found[KEY_A].lastPreview))
    assert(found[KEY_A].unreadCount == 1, "the whispered card shows the new unread count, got " .. tostring(found[KEY_A].unreadCount))
    assert(found[KEY_C] ~= nil and found[KEY_C].displayName == "C", "an untouched chat keeps its card")
  end
end
