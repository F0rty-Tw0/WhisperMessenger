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
  }
end

local function normalizeKey(name)
  if name == nil or name == "" then
    return ""
  end
  return string.lower(name)
end

local function baseName(key)
  return string.match(key, "^([^-]+)") or key
end

local function evictOldest(state)
  local count = 0
  for _ in pairs(state.entries) do
    count = count + 1
  end
  if count <= state.maxEntries then
    return
  end

  local oldestKey = nil
  local oldestTime = math.huge
  for key, entry in pairs(state.entries) do
    if entry.sentAt < oldestTime then
      oldestTime = entry.sentAt
      oldestKey = key
    end
  end

  if oldestKey then
    local evicted = state.entries[oldestKey]
    state.entries[oldestKey] = nil
    -- Clean base index if it points to the evicted entry
    local base = baseName(oldestKey)
    if state.baseIndex[base] == evicted then
      state.baseIndex[base] = nil
    end
  end
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

  local entry = {
    text = text,
    channelLabel = channelLabel,
    playerName = senderName,
    sentAt = sentAt,
  }

  state.entries[key] = entry
  state.baseIndex[baseName(key)] = entry

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
