local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationSnapshot = ns.ConversationSnapshot or require("WhisperMessenger.Model.ConversationSnapshot")
local PerfCounters = ns.PerfCounters or require("WhisperMessenger.Util.PerfCounters")

-- Contact snapshots kept between incoming-line refreshes. Contact enrichers
-- write status onto the returned card in place, so each entry also keeps an
-- untouched base: a reused card is reset from it field by field, which can't
-- miss a field a future enricher adds.
local SnapshotCache = {}

function SnapshotCache.New()
  return {}
end

local function shallowCopy(source)
  local copy = {}
  for key, value in pairs(source) do
    copy[key] = value
  end
  return copy
end

local function restore(card, base)
  for key in pairs(card) do
    card[key] = base[key]
  end
  for key, value in pairs(base) do
    card[key] = value
  end
end

-- dirtyKeys nil means a full rebuild; otherwise only listed keys rebuild.
-- Code that writes to a conversation without a full refresh must mark its
-- key dirty, or the cached card keeps the old values (drafts rely on the
-- full refresh a selection change does).
function SnapshotCache.Get(cache, conversationKey, conversation, settings, dirtyKeys)
  local entry = cache[conversationKey]
  if dirtyKeys == nil or dirtyKeys[conversationKey] or entry == nil or entry.conversation ~= conversation then
    if entry == nil then
      entry = {}
      cache[conversationKey] = entry
    end
    PerfCounters.Increment("snapshotBuilds")
    entry.conversation = conversation
    entry.base = ConversationSnapshot.Build(conversationKey, conversation, settings)
    entry.card = shallowCopy(entry.base)
    return entry.card
  end
  restore(entry.card, entry.base)
  return entry.card
end

-- Drops entries whose conversation left the store.
function SnapshotCache.Prune(cache, liveKeys)
  for conversationKey in pairs(cache) do
    if liveKeys[conversationKey] == nil then
      cache[conversationKey] = nil
    end
  end
end

ns.ContactsListSnapshotCache = SnapshotCache
return SnapshotCache
