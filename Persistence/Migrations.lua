local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

local Migrations = {
  CURRENT_VERSION = 5,
}

local function isFlatChannelShape(channelMessages)
  if type(channelMessages) ~= "table" then
    return false
  end
  if type(channelMessages.entries) == "table" then
    return true
  end
  if next(channelMessages) == nil then
    return true
  end
  return false
end

local function entrySequence(entry)
  return tonumber(entry and entry.sequence) or 0
end

local function shouldReplace(existing, candidate)
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

local function flattenPerProfileChannelMessages(legacy)
  local flat = { entries = {}, nextSequence = 0 }
  for _, bucket in pairs(legacy) do
    if type(bucket) == "table" then
      local bucketSequence = tonumber(bucket.nextSequence)
      if bucketSequence and bucketSequence > flat.nextSequence then
        flat.nextSequence = bucketSequence
      end
      local bucketEntries = type(bucket.entries) == "table" and bucket.entries or nil
      if bucketEntries then
        for key, entry in pairs(bucketEntries) do
          if type(entry) == "table" and type(entry.sentAt) == "number" then
            if shouldReplace(flat.entries[key], entry) then
              flat.entries[key] = entry
            end
            local seq = entrySequence(entry)
            if seq > flat.nextSequence then
              flat.nextSequence = seq
            end
          end
        end
      end
    end
  end
  return flat
end

function Migrations.Apply(accountState, schema)
  accountState = accountState or schema.NewAccountState()

  if accountState.schemaVersion == nil then
    accountState.schemaVersion = Migrations.CURRENT_VERSION
  end

  if accountState.conversations == nil then
    accountState.conversations = {}
  end

  if accountState.contacts == nil then
    accountState.contacts = {}
  end

  if accountState.pendingHydration == nil then
    accountState.pendingHydration = {}
  end

  if accountState.channelMessages == nil then
    accountState.channelMessages = {}
  elseif not isFlatChannelShape(accountState.channelMessages) then
    accountState.channelMessages = flattenPerProfileChannelMessages(accountState.channelMessages)
  end

  -- Strip legacy AFK/DND system messages from saved conversations
  for _, conv in pairs(accountState.conversations) do
    if conv.messages then
      local filtered = {}
      for _, msg in ipairs(conv.messages) do
        if msg.eventName ~= "CHAT_MSG_AFK" and msg.eventName ~= "CHAT_MSG_DND" then
          filtered[#filtered + 1] = msg
        end
      end
      conv.messages = filtered
    end
  end

  -- Backfill channel type on existing whisper/bnet conversations (v4 -> v5).
  -- Idempotent: only stamps records where channel is nil.
  for key, conv in pairs(accountState.conversations) do
    if conv.channel == nil then
      if type(key) == "string" and string.find(key, "wow::", 1, true) == 1 then
        conv.channel = ChannelType.WHISPER
      elseif type(key) == "string" and string.find(key, "bnet::", 1, true) == 1 then
        conv.channel = ChannelType.BN_WHISPER
      end
      -- Unknown/ambiguous keys: leave channel nil; later-stage ingest will supply it.
    end
  end

  accountState.schemaVersion = Migrations.CURRENT_VERSION
  return accountState
end

ns.Migrations = Migrations

return Migrations
