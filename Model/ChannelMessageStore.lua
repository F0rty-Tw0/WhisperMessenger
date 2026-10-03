local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelMessageStore = {}

local DEFAULT_MAX_ENTRIES = 200
local DEFAULT_TTL_SECONDS = 1800 -- 30 minutes

-- The store table is saved as-is in SavedVariables, so its lookup indexes live
-- here instead and are rebuilt from entries the first time a store is used.
local indexes = setmetatable({}, { __mode = "k" })

function ChannelMessageStore.New(config)
  config = config or {}
  return {
    entries = {},
    entryCount = 0,
    maxEntries = config.maxEntries or DEFAULT_MAX_ENTRIES,
    ttl = config.ttl or DEFAULT_TTL_SECONDS,
    nextSequence = tonumber(config.nextSequence) or 0,
  }
end

local function lowerName(name)
  if name == nil or name == "" then
    return ""
  end
  return string.lower(name)
end

local function normalizeKey(name)
  local ok, result = pcall(lowerName, name)
  -- If name is a secret/tainted value, comparison throws; treat as empty.
  return ok and result or ""
end

local function baseName(key)
  return string.match(key, "^([^-]+)") or key
end

local function countEntries(state)
  return tonumber(state.entryCount) or 0
end

local function entrySequence(entry)
  return tonumber(entry and entry.sequence) or 0
end

-- Age order: earlier sentAt first, then earlier sequence for equal times.
local function isOlder(entry, other)
  local entrySentAt = entry.sentAt or 0
  local otherSentAt = other.sentAt or 0
  if entrySentAt ~= otherSentAt then
    return entrySentAt < otherSentAt
  end
  return entrySequence(entry) < entrySequence(other)
end

local function trackBase(index, state, key, entry, isNewKey)
  local base = baseName(key)
  if isNewKey then
    index.baseCount[base] = (index.baseCount[base] or 0) + 1
  end
  local latestKey = index.baseLatest[base]
  local latest = latestKey and state.entries[latestKey]
  if not latest or isOlder(latest, entry) then
    index.baseLatest[base] = key
  end
end

-- The queue holds every recorded line oldest first, from head to tail. A slot
-- whose entry was since replaced or removed is stale and skipped.
local function isLive(state, key, entry)
  return state.entries[key] == entry
end

local function buildIndex(state)
  local index = { queueKeys = {}, queueEntries = {}, head = 1, tail = 0, baseLatest = {}, baseCount = {} }
  local keys = index.queueKeys
  for key in pairs(state.entries) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(a, b)
    return isOlder(state.entries[a], state.entries[b])
  end)
  for i, key in ipairs(keys) do
    local entry = state.entries[key]
    index.queueEntries[i] = entry
    trackBase(index, state, key, entry, true)
  end
  index.tail = #keys
  return index
end

local function indexFor(state)
  local index = indexes[state]
  if index == nil then
    index = buildIndex(state)
    indexes[state] = index
  end
  return index
end

local function enqueue(index, key, entry)
  local keys, entries = index.queueKeys, index.queueEntries
  local slot = index.tail + 1
  -- Lines arrive in time order almost always; walk back only for one that didn't.
  while slot > index.head and isOlder(entry, entries[slot - 1]) do
    keys[slot], entries[slot] = keys[slot - 1], entries[slot - 1]
    slot = slot - 1
  end
  keys[slot], entries[slot] = key, entry
  index.tail = index.tail + 1
end

local function compactQueue(state, index)
  local keys, entries = index.queueKeys, index.queueEntries
  local write = 0
  for read = index.head, index.tail do
    local key, entry = keys[read], entries[read]
    keys[read], entries[read] = nil, nil
    if isLive(state, key, entry) then
      write = write + 1
      keys[write], entries[write] = key, entry
    end
  end
  index.head, index.tail = 1, write
end

local function removeEntry(state, index, key)
  if state.entries[key] == nil then
    return false
  end

  state.entries[key] = nil
  state.entryCount = math.max(0, countEntries(state) - 1)

  local base = baseName(key)
  local remaining = (index.baseCount[base] or 1) - 1
  if remaining <= 0 then
    index.baseCount[base] = nil
    index.baseLatest[base] = nil
    return true
  end

  index.baseCount[base] = remaining
  if index.baseLatest[base] == key then
    -- Only reached when one name posts from several realms and the newest
    -- of them expires first; eviction always takes the older ones before it.
    index.baseLatest[base] = nil
    for candidateKey, candidate in pairs(state.entries) do
      if baseName(candidateKey) == base then
        trackBase(index, state, candidateKey, candidate, false)
      end
    end
  end
  return true
end

local function evictOverflow(state, index)
  local keys, entries = index.queueKeys, index.queueEntries
  while countEntries(state) > state.maxEntries and index.head <= index.tail do
    local key, entry = keys[index.head], entries[index.head]
    keys[index.head], entries[index.head] = nil, nil
    index.head = index.head + 1
    if isLive(state, key, entry) then
      removeEntry(state, index, key)
    end
  end
end

local function normalizeEntry(entry)
  if type(entry) ~= "table" then
    return nil
  end

  local sentAt = tonumber(entry.sentAt)
  if sentAt == nil then
    return nil
  end

  return {
    text = entry.text,
    channelLabel = entry.channelLabel,
    playerName = entry.playerName,
    sentAt = sentAt,
    sequence = entrySequence(entry),
  }
end

local function pruneExpiredEntries(state, now)
  for key, entry in pairs(state.entries) do
    if (now - entry.sentAt) > state.ttl then
      state.entries[key] = nil
      state.entryCount = state.entryCount - 1
    end
  end
end

function ChannelMessageStore.Restore(savedState, config, now)
  local restored = ChannelMessageStore.New(config)
  if type(savedState) == "table" and type(savedState.nextSequence) == "number" then
    restored.nextSequence = savedState.nextSequence
  end

  local savedEntries = type(savedState) == "table" and savedState.entries or nil
  if type(savedEntries) ~= "table" then
    return restored
  end

  for key, entry in pairs(savedEntries) do
    local normalizedKey = normalizeKey(key)
    local normalizedEntry = normalizeEntry(entry)
    if normalizedKey ~= "" and normalizedEntry ~= nil then
      if restored.entries[normalizedKey] == nil then
        restored.entryCount = restored.entryCount + 1
      end
      restored.entries[normalizedKey] = normalizedEntry
      restored.nextSequence = math.max(restored.nextSequence, entrySequence(normalizedEntry))
    end
  end

  if type(now) == "number" then
    pruneExpiredEntries(restored, now)
  end

  evictOverflow(restored, indexFor(restored))
  return restored
end

function ChannelMessageStore.Record(state, senderName, text, channelLabel, sentAt)
  local key = normalizeKey(senderName)
  if key == "" then
    return
  end

  local existing = state.entries[key]
  if existing and existing.sentAt > sentAt then
    return
  end

  local index = indexFor(state)
  state.nextSequence = (tonumber(state.nextSequence) or 0) + 1
  local entry = {
    text = text,
    channelLabel = channelLabel,
    playerName = senderName,
    sentAt = sentAt,
    sequence = state.nextSequence,
  }

  state.entries[key] = entry
  if existing == nil then
    state.entryCount = countEntries(state) + 1
  end
  trackBase(index, state, key, entry, existing == nil)
  enqueue(index, key, entry)

  evictOverflow(state, index)
  -- Stale slots from senders who posted again pile up below the cap; dropping
  -- them once the queue doubles keeps the cleanup O(1) per line on average.
  if index.tail - index.head >= 2 * state.maxEntries then
    compactQueue(state, index)
  end
end

function ChannelMessageStore.GetLatest(state, canonicalName, now)
  local key = normalizeKey(canonicalName)
  if key == "" then
    return nil
  end

  local entryKey = key
  local entry = state.entries[key]
  if not entry then
    -- Fallback: try base name match
    entryKey = indexFor(state).baseLatest[baseName(key)]
    if entryKey then
      entry = state.entries[entryKey]
    end
  end

  if not entry then
    return nil
  end

  -- Expiry check
  if now and (now - entry.sentAt) > state.ttl then
    removeEntry(state, indexFor(state), entryKey)
    return nil
  end

  return entry
end

ns.ChannelMessageStore = ChannelMessageStore
return ChannelMessageStore
