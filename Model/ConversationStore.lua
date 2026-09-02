local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Retention = ns.Retention
if not Retention then
  local ok, loaded = pcall(require, "WhisperMessenger.Model.Retention")
  if ok then
    Retention = loaded
  end
end

assert(Retention, "Retention module not available")

local Store = {}

local REMOVAL_REASON_CAPACITY = "capacity"
local REMOVAL_REASON_EXPLICIT = "explicit"
local REMOVAL_REASON_RETENTION = "retention"

function Store.New(config, now)
  return {
    config = config or {},
    conversations = {},
    now = now,
    messageRetentionAt = {},
  }
end

local function newConversation(key)
  return {
    messages = {},
    unreadCount = 0,
    unreadActivityCount = 0,
    lastPreview = nil,
    lastActivityAt = 0,
    lastActivityLineID = nil,
    lastIncomingSender = nil,
    lastIncomingPreview = nil,
    lastIncomingAt = nil,
    lastIncomingLineID = nil,
    guid = nil,
    bnetAccountID = nil,
    battleTag = nil,
    gameAccountName = nil,
    className = nil,
    classTag = nil,
    raceName = nil,
    raceTag = nil,
    factionName = nil,
    conversationKey = key,
  }
end

local function removeConversation(state, key, reason)
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

local function evictOldestConversation(state, protectedKey)
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
    -- Pinned conversations are exempt from every retention path. The key
    -- currently being appended is also protected so all-pinned histories
    -- soft-overflow instead of dropping the new message.
    if key ~= protectedKey and conv.pinned ~= true then
      local activity = conv.lastActivityAt or 0
      if activity < oldestTime or (activity == oldestTime and (oldestKey == nil or key < oldestKey)) then
        oldestTime = activity
        oldestKey = key
      end
    end
  end

  if oldestKey then
    removeConversation(state, oldestKey, REMOVAL_REASON_CAPACITY)
    return oldestKey
  end
  return nil
end

local CONVERSATION_METADATA_FIELDS = {
  "channel",
  "displayName",
  "contactDisplayName",
  "guid",
  "bnetAccountID",
  "battleTag",
  "gameAccountName",
  "className",
  "classTag",
  "raceName",
  "raceTag",
  "factionName",
  "conversationID",
  "lastActivityAt",
}

local function compactMessage(message)
  message.eventName = nil
  message.className = nil
  message.raceName = nil
  message.raceTag = nil
  message.factionName = nil
end

function Store.EnsureConversation(state, key, metadata)
  state.conversations = state.conversations or {}
  local conversation = state.conversations[key]
  if conversation ~= nil then
    return conversation, false
  end

  conversation = newConversation(key)
  if type(metadata) == "table" then
    for _, field in ipairs(CONVERSATION_METADATA_FIELDS) do
      if metadata[field] ~= nil then
        conversation[field] = metadata[field]
      end
    end
  end
  state.conversations[key] = conversation
  evictOldestConversation(state, key)
  return conversation, true
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
    boundary = earlierBoundary(boundary, message.sentAt, maxAge)
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

local function applyRetentionAfterAppend(state, key, conversation, message)
  local now = type(state.now) == "function" and state.now() or message.sentAt
  Retention.TrimMessages(conversation.messages, state.config.maxMessagesPerConversation)

  state.messageRetentionAt = state.messageRetentionAt or {}
  local trackedBoundary = state.messageRetentionAt[key]
  if not conversation.pinned and trackedBoundary ~= nil then
    state.messageRetentionAt[key] = earlierBoundary(trackedBoundary, message.sentAt, state.config.messageMaxAge)
  end

  for conversationKey, candidate in pairs(state.conversations) do
    if conversationKey ~= key and not candidate.pinned and Retention.IsExpired(candidate.lastActivityAt, state.config.conversationMaxAge, now) then
      removeConversation(state, conversationKey, REMOVAL_REASON_RETENTION)
    else
      expireConversationMessages(state, conversationKey, candidate, now, false)
    end
  end

  while true do
    if evictOldestConversation(state, key) == nil then
      break
    end
  end
end

local function isIncomingUserMessage(message)
  return message ~= nil and message.kind == "user" and message.direction == "in"
end

local function isOutgoingUserMessage(message)
  return message ~= nil and message.kind == "user" and message.direction == "out"
end

local function applyActivityMetadata(conversation, message)
  conversation.lastPreview = message.text
  conversation.lastActivityAt = message.sentAt
  conversation.lastActivityLineID = message.lineID
end

local function applyIncomingMetadata(conversation, message)
  conversation.lastIncomingSender = message.playerName or conversation.lastIncomingSender
  conversation.lastIncomingPreview = message.text
  conversation.lastIncomingAt = message.sentAt
  conversation.lastIncomingLineID = message.lineID
end

local function applyContactMetadata(state, key, conversation, message)
  local oldGuid = conversation.guid
  conversation.displayName = message.playerName or conversation.displayName
  conversation.channel = message.channel or conversation.channel or "WOW"
  conversation.guid = message.guid or conversation.guid
  conversation.bnetAccountID = message.bnetAccountID or conversation.bnetAccountID
  conversation.battleTag = message.battleTag or conversation.battleTag
  conversation.gameAccountName = message.gameAccountName or conversation.gameAccountName
  conversation.className = message.className or conversation.className
  conversation.classTag = message.classTag or conversation.classTag
  conversation.raceName = message.raceName or conversation.raceName
  conversation.raceTag = message.raceTag or conversation.raceTag
  conversation.factionName = message.factionName or conversation.factionName

  if oldGuid ~= nil and conversation.guid ~= oldGuid and type(state.onConversationGUIDChanged) == "function" then
    state.onConversationGUIDChanged(key, oldGuid, conversation.guid)
  end
end

local function applyMessageMetadata(state, key, conversation, message)
  applyActivityMetadata(conversation, message)
  if isIncomingUserMessage(message) then
    applyIncomingMetadata(conversation, message)
  end
  applyContactMetadata(state, key, conversation, message)
end

local function isLatestMetadata(message, latestAt, latestLineID)
  local sentAt = tonumber(message.sentAt) or 0
  local latestSentAt = tonumber(latestAt) or 0
  if sentAt ~= latestSentAt then
    return sentAt > latestSentAt
  end

  local lineID = tonumber(message.lineID)
  local latestLineIDNumber = tonumber(latestLineID)
  return lineID == nil or latestLineIDNumber == nil or lineID >= latestLineIDNumber
end

local function shouldIncrementUnread(message)
  return isIncomingUserMessage(message)
end

function Store.AppendIncoming(state, key, message, isActive)
  local conversation = Store.EnsureConversation(state, key)
  table.insert(conversation.messages, message)
  applyMessageMetadata(state, key, conversation, message)
  compactMessage(message)
  applyRetentionAfterAppend(state, key, conversation, message)

  if message.kind == "user" and message.direction == "in" then
    conversation.activeStatus = nil
  end

  if not isActive and shouldIncrementUnread(message) then
    conversation.unreadCount = conversation.unreadCount + 1
  end
end
function Store.RecordIncomingActivity(state, key, message, isActive)
  local conversation = Store.EnsureConversation(state, key)
  if isLatestMetadata(message, conversation.lastActivityAt, conversation.lastActivityLineID) then
    applyActivityMetadata(conversation, message)
  end
  if isIncomingUserMessage(message) and isLatestMetadata(message, conversation.lastIncomingAt, conversation.lastIncomingLineID) then
    applyIncomingMetadata(conversation, message)
  end
  if not isActive and shouldIncrementUnread(message) then
    conversation.unreadCount = (conversation.unreadCount or 0) + 1
    conversation.unreadActivityCount = (conversation.unreadActivityCount or 0) + 1
  end
  return conversation
end

function Store.InsertIncomingChronological(state, key, message, isActive)
  local conversation = Store.EnsureConversation(state, key)
  local messages = conversation.messages
  local sentAt = tonumber(message.sentAt) or 0
  local lineID = tonumber(message.lineID)
  local insertAt = #messages + 1
  for index, existing in ipairs(messages) do
    local existingSentAt = tonumber(existing.sentAt) or 0
    local existingLineID = tonumber(existing.lineID)
    if existingSentAt > sentAt or (existingSentAt == sentAt and lineID and existingLineID and existingLineID > lineID) then
      insertAt = index
      break
    end
  end
  local isNewest = insertAt == #messages + 1
  table.insert(messages, insertAt, message)

  applyRetentionAfterAppend(state, key, conversation, message)
  local storedConversation = state.conversations[key]
  if storedConversation ~= conversation then
    return storedConversation
  end

  local messageIndex
  for index, retainedMessage in ipairs(conversation.messages) do
    if retainedMessage == message then
      messageIndex = index
      break
    end
  end
  if messageIndex == nil then
    local now = type(state.now) == "function" and state.now() or message.sentAt
    if not conversation.pinned and Retention.IsExpired(conversation.lastActivityAt, state.config.conversationMaxAge, now) then
      removeConversation(state, key, REMOVAL_REASON_RETENTION)
    end
    return state.conversations[key]
  end

  local updatesLatestActivity = isNewest and isLatestMetadata(message, conversation.lastActivityAt, conversation.lastActivityLineID)
  local prospectiveLastActivityAt = conversation.lastActivityAt
  if updatesLatestActivity then
    prospectiveLastActivityAt = message.sentAt
  end
  local now = type(state.now) == "function" and state.now() or message.sentAt
  if not conversation.pinned and Retention.IsExpired(prospectiveLastActivityAt, state.config.conversationMaxAge, now) then
    table.remove(messages, messageIndex)
    removeConversation(state, key, REMOVAL_REASON_RETENTION)
    return nil
  end

  if isNewest then
    if updatesLatestActivity then
      applyActivityMetadata(conversation, message)
    end
    if isIncomingUserMessage(message) and isLatestMetadata(message, conversation.lastIncomingAt, conversation.lastIncomingLineID) then
      applyIncomingMetadata(conversation, message)
    end
    applyContactMetadata(state, key, conversation, message)
  end
  local activeStatus = conversation.activeStatus
  local statusSentAt = activeStatus and tonumber(activeStatus.sentAt)
  local statusLineID = activeStatus and tonumber(activeStatus.lineID)
  local supersedesStatus = statusSentAt == nil
    or sentAt > statusSentAt
    or (sentAt == statusSentAt and (lineID == nil or statusLineID == nil or lineID >= statusLineID))
  if supersedesStatus and message.kind == "user" and message.direction == "in" then
    conversation.activeStatus = nil
  end
  compactMessage(message)
  if not isActive and shouldIncrementUnread(message) then
    conversation.unreadCount = conversation.unreadCount + 1
  end
  return conversation
end

function Store.AppendOutgoing(state, key, message)
  local conversation = Store.EnsureConversation(state, key)
  table.insert(conversation.messages, message)
  applyMessageMetadata(state, key, conversation, message)
  compactMessage(message)
  applyRetentionAfterAppend(state, key, conversation, message)
end

function Store.SetActiveStatus(state, key, status)
  local conversation = Store.EnsureConversation(state, key)
  conversation.activeStatus = status
end

function Store.ClearActiveStatus(state, key)
  local conversation = state.conversations[key]
  if conversation then
    conversation.activeStatus = nil
  end
end

function Store.MarkRead(state, key)
  local conversation = Store.EnsureConversation(state, key)
  conversation.unreadCount = 0
  conversation.unreadActivityCount = 0
end

function Store.CountUnansweredIncoming(conversation)
  if type(conversation) ~= "table" then
    return 0
  end

  local count = 0
  local messages = conversation.messages or {}
  for index = #messages, 1, -1 do
    local message = messages[index]
    if isOutgoingUserMessage(message) and message.delivery ~= "blocked" then
      break
    end
    if isIncomingUserMessage(message) then
      count = count + 1
    end
  end
  return count
end

function Store.ApplyRetention(state, now, protectedKey)
  state.conversations = state.conversations or {}
  state.messageRetentionAt = {}
  local removed = {}

  for key, conversation in pairs(state.conversations) do
    if not conversation.pinned and Retention.IsExpired(conversation.lastActivityAt, state.config.conversationMaxAge, now) then
      removeConversation(state, key, REMOVAL_REASON_RETENTION)
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
    local key = evictOldestConversation(state, protectedKey)
    if key == nil then
      break
    end
    removed[key] = true
  end

  return removed
end
function Store.MarkUnread(state, key)
  local conversation = Store.EnsureConversation(state, key)
  conversation.unreadCount = Store.CountUnansweredIncoming(conversation) + (conversation.unreadActivityCount or 0)
end

function Store.Pin(state, key)
  local conversation = state.conversations[key]
  if conversation then
    conversation.pinned = true
    if state.messageRetentionAt then
      state.messageRetentionAt[key] = nil
    end
  end
end

function Store.Unpin(state, key)
  local conversation = state.conversations[key]
  if conversation then
    conversation.pinned = false
    Store.ExpireAll(state)
    evictOldestConversation(state)
  end
end

function Store.IsPinned(state, key)
  local conversation = state.conversations[key]
  if conversation and conversation.pinned then
    return true
  end
  return false
end

function Store.Remove(state, key)
  return removeConversation(state, key, REMOVAL_REASON_EXPLICIT)
end

function Store.SetSortOrder(state, key, order)
  local conversation = state.conversations[key]
  if conversation then
    conversation.sortOrder = order
  end
end

function Store.SwapOrder(state, keyA, keyB)
  local a = state.conversations[keyA]
  local b = state.conversations[keyB]
  if a and b then
    local tmp = a.sortOrder or 0
    a.sortOrder = b.sortOrder or 0
    b.sortOrder = tmp
  end
end

function Store.ExpireAll(state, now)
  state.messageRetentionAt = {}
  for key, conversation in pairs(state.conversations) do
    if not conversation.pinned and Retention.IsExpired(conversation.lastActivityAt, state.config.conversationMaxAge, now) then
      removeConversation(state, key, REMOVAL_REASON_RETENTION)
    else
      Retention.TrimMessages(conversation.messages, state.config.maxMessagesPerConversation)
      expireConversationMessages(state, key, conversation, now, true)
    end
  end
end

ns.ConversationStore = Store

return Store
