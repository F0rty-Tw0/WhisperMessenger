local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Retention = ns.Retention or require("WhisperMessenger.Model.Retention")

-- How conversations and messages leave the ConversationStore: age and
-- count limits, capacity eviction and explicit removal. Pinned
-- conversations and queued messages are exempt from every limit.
local StoreRetention = {}

StoreRetention.REASON_CAPACITY = "capacity"
StoreRetention.REASON_EXPLICIT = "explicit"
StoreRetention.REASON_RETENTION = "retention"

function StoreRetention.Remove(state, key, reason)
  local conversation = state.conversations[key]
  if conversation == nil then
    return nil
  end

  if state.messageRetentionAt then
    state.messageRetentionAt[key] = nil
  end
  state.conversations[key] = nil
  if type(state.onConversationRemoved) == "function" then
    state.onConversationRemoved(key, conversation, reason)
  end
  return conversation
end

local function hasQueuedMessage(conversation)
  for _, message in ipairs(conversation.messages or {}) do
    if Retention.IsQueued(message) then
      return true
    end
  end
  return false
end

-- Pinning is the only "keep forever" switch; a queued message is kept so it
-- is never dropped unsent. Everything else follows the retention timeout.
local function isRetained(conversation)
  return conversation.pinned == true or hasQueuedMessage(conversation)
end

function StoreRetention.IsExpired(state, conversation, lastActivityAt, now)
  return Retention.IsExpired(lastActivityAt, state.config.conversationMaxAge, now) and not isRetained(conversation)
end

-- Removes the least recently active conversation while over capacity.
-- Returns the removed key, or nil when nothing was evicted.
function StoreRetention.EvictOldest(state, protectedKey)
  local maxConversations = state.config and state.config.maxConversations
  if type(maxConversations) ~= "number" or maxConversations < 1 then
    return
  end

  local count = 0
  for _ in pairs(state.conversations) do
    count = count + 1
  end

  if count <= maxConversations then
    return
  end

  local oldestKey = nil
  local oldestTime = math.huge
  for key, conv in pairs(state.conversations) do
    -- Retained conversations are exempt from every retention path. The key
    -- currently being appended is also protected so all-retained histories
    -- soft-overflow instead of dropping the new message.
    if key ~= protectedKey and not isRetained(conv) then
      local activity = conv.lastActivityAt or 0
      if activity < oldestTime or (activity == oldestTime and (oldestKey == nil or key < oldestKey)) then
        oldestTime = activity
        oldestKey = key
      end
    end
  end

  if oldestKey then
    StoreRetention.Remove(state, oldestKey, StoreRetention.REASON_CAPACITY)
    return oldestKey
  end
  return nil
end

local function earlierBoundary(current, timestamp, maxAge)
  if type(timestamp) ~= "number" or timestamp == 0 or type(maxAge) ~= "number" then
    return current
  end
  local candidate = timestamp + maxAge
  if current == nil or candidate < current then
    return candidate
  end
  return current
end

local function findMessageRetentionBoundary(conversation, maxAge)
  local boundary
  for _, message in ipairs(conversation.messages or {}) do
    -- Queued messages never expire, so they set no boundary.
    if not Retention.IsQueued(message) then
      boundary = earlierBoundary(boundary, message.sentAt, maxAge)
    end
  end
  return boundary or math.huge
end

local function expireConversationMessages(state, key, conversation, now, force)
  state.messageRetentionAt = state.messageRetentionAt or {}
  if conversation.pinned then
    state.messageRetentionAt[key] = nil
    return
  end

  local boundary = state.messageRetentionAt[key]
  if boundary == nil then
    boundary = findMessageRetentionBoundary(conversation, state.config.messageMaxAge)
  end
  if force or type(now) ~= "number" or now > boundary then
    Retention.ExpireMessages(conversation.messages, state.config.messageMaxAge, now)
    boundary = findMessageRetentionBoundary(conversation, state.config.messageMaxAge)
  end
  state.messageRetentionAt[key] = boundary
end

-- Runs after every append to conversation `key`.
function StoreRetention.AfterAppend(state, key, conversation, message)
  local now = type(state.now) == "function" and state.now() or message.sentAt
  Retention.TrimMessages(conversation.messages, state.config.maxMessagesPerConversation)

  state.messageRetentionAt = state.messageRetentionAt or {}
  local trackedBoundary = state.messageRetentionAt[key]
  if not conversation.pinned and trackedBoundary ~= nil then
    state.messageRetentionAt[key] = earlierBoundary(trackedBoundary, message.sentAt, state.config.messageMaxAge)
  end

  for conversationKey, candidate in pairs(state.conversations) do
    if conversationKey ~= key and StoreRetention.IsExpired(state, candidate, candidate.lastActivityAt, now) then
      StoreRetention.Remove(state, conversationKey, StoreRetention.REASON_RETENTION)
    else
      expireConversationMessages(state, conversationKey, candidate, now, false)
    end
  end

  while true do
    if StoreRetention.EvictOldest(state, key) == nil then
      break
    end
  end
end

-- Full pass (load, window open, status tick). Returns the removed keys.
function StoreRetention.Apply(state, now, protectedKey)
  state.conversations = state.conversations or {}
  state.messageRetentionAt = {}
  local removed = {}

  for key, conversation in pairs(state.conversations) do
    if StoreRetention.IsExpired(state, conversation, conversation.lastActivityAt, now) then
      StoreRetention.Remove(state, key, StoreRetention.REASON_RETENTION)
      removed[key] = true
    else
      local messages = conversation.messages
      if messages then
        Retention.TrimMessages(messages, state.config.maxMessagesPerConversation)
        expireConversationMessages(state, key, conversation, now, true)
      end
    end
  end

  while true do
    local key = StoreRetention.EvictOldest(state, protectedKey)
    if key == nil then
      break
    end
    removed[key] = true
  end

  return removed
end

function StoreRetention.ExpireAll(state, now)
  state.messageRetentionAt = {}
  for key, conversation in pairs(state.conversations) do
    if StoreRetention.IsExpired(state, conversation, conversation.lastActivityAt, now) then
      StoreRetention.Remove(state, key, StoreRetention.REASON_RETENTION)
    else
      Retention.TrimMessages(conversation.messages, state.config.maxMessagesPerConversation)
      expireConversationMessages(state, key, conversation, now, true)
    end
  end
end

ns.ConversationStoreRetention = StoreRetention
return StoreRetention
