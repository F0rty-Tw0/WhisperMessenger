local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelMessageStore = {}

local DEFAULT_MAX_ENTRIES = 200
local DEFAULT_TTL_SECONDS = 1800 -- 30 minutes

function ChannelMessageStore.New(config)
  config = config or {}
  return {
    entries = {},
    baseIndex = {},
    maxEntries = config.maxEntries or DEFAULT_MAX_ENTRIES,
    ttl = config.ttl or DEFAULT_TTL_SECONDS,
    nextSequence = tonumber(config.nextSequence) or 0,
  }
end

local function normalizeKey(name)
  local ok, result = pcall(function()
    if name == nil or name == "" then
      return ""
    end
    return string.lower(name)
  end)
  -- If name is a secret/tainted value, comparison throws; treat as empty.
  return ok and result or ""
end

local function baseName(key)
  return string.match(key, "^([^-]+)") or key
end

local function countEntries(state)
  local count = 0
  for _ in pairs(state.entries) do
    count = count + 1
  end
  return count
end

local function entrySequence(entry)
  return tonumber(entry and entry.sequence) or 0
end

local function shouldPreferEntry(existing, candidate)
  if existing == nil then
    return true
  end

  local existingSentAt = existing.sentAt or 0
  local candidateSentAt = candidate.sentAt or 0
  if existingSentAt ~= candidateSentAt then
    return existingSentAt < candidateSentAt
  end

  return entrySequence(existing) < entrySequence(candidate)
end

local function rememberBaseEntry(state, key, entry)
  local base = baseName(key)
  local existing = state.baseIndex[base]
  if shouldPreferEntry(existing, entry) then
    state.baseIndex[base] = entry
  end
end

local function rebuildBaseIndex(state)
  state.baseIndex = {}
  for key, entry in pairs(state.entries) do
    rememberBaseEntry(state, key, entry)
  end
end

local function pruneExpiredEntries(state, now)
  local expiredKeys = {}
  for key, entry in pairs(state.entries) do
    if type(entry) ~= "table" or type(entry.sentAt) ~= "number" or (now - entry.sentAt) > state.ttl then
      expiredKeys[#expiredKeys + 1] = key
    end
  end

  for _, key in ipairs(expiredKeys) do
    state.entries[key] = nil
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

local function evictOldest(state)
  if countEntries(state) <= state.maxEntries then
    return
  end

  local oldestKey = nil
  local oldestTime = math.huge
  local oldestSequence = math.huge
  for key, entry in pairs(state.entries) do
    local entrySentAt = entry.sentAt or 0
    local entrySequenceValue = entrySequence(entry)
    if entrySentAt < oldestTime or (entrySentAt == oldestTime and entrySequenceValue < oldestSequence) then
      oldestTime = entrySentAt
      oldestSequence = entrySequenceValue
      oldestKey = key
    end
  end

  if oldestKey then
    local evicted = state.entries[oldestKey]
    state.entries[oldestKey] = nil
    local base = baseName(oldestKey)
    if state.baseIndex[base] == evicted then
      rebuildBaseIndex(state)
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
      restored.entries[normalizedKey] = normalizedEntry
      restored.nextSequence = math.max(restored.nextSequence, entrySequence(normalizedEntry))
    end
  end

  if type(now) == "number" then
    pruneExpiredEntries(restored, now)
  end

  rebuildBaseIndex(restored)
  while countEntries(restored) > restored.maxEntries do
    evictOldest(restored)
  end

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

  state.nextSequence = (tonumber(state.nextSequence) or 0) + 1
  local entry = {
    text = text,
    channelLabel = channelLabel,
    playerName = senderName,
    sentAt = sentAt,
    sequence = state.nextSequence,
  }

  state.entries[key] = entry
  rememberBaseEntry(state, key, entry)

  evictOldest(state)
end

function ChannelMessageStore.GetLatest(state, canonicalName, now)
  local key = normalizeKey(canonicalName)
  if key == "" then
    return nil
  end

  local entry = state.entries[key]
  if not entry then
    -- Fallback: try base name match
    local base = baseName(key)
    entry = state.baseIndex[base]
  end

  if not entry then
    return nil
  end

  -- Expiry check
  if now and (now - entry.sentAt) > state.ttl then
    return nil
  end

  return entry
end

ns.ChannelMessageStore = ChannelMessageStore
return ChannelMessageStore
