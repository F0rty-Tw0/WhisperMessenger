local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- stylua: ignore start
local StoreRetention = ns.ConversationStoreRetention or require("WhisperMessenger.Model.ConversationStore.StoreRetention")
local MessageMetadata = ns.ConversationStoreMessageMetadata or require("WhisperMessenger.Model.ConversationStore.MessageMetadata")
-- stylua: ignore end

local Store = {}

function Store.New(config, now)
  return {
    config = config or {},
    conversations = {},
    now = now,
    messageRetentionAt = {},
  }
end

-- The conversation stored under key, or nil (also for a nil store or key).
function Store.Find(state, key)
  local conversations = state and state.conversations
  if conversations == nil or key == nil then
    return nil
  end
  return conversations[key]
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
  StoreRetention.EvictOldest(state, key)
  return conversation, true
end

local function shouldIncrementUnread(message)
  return MessageMetadata.IsIncomingUser(message)
end

function Store.AppendIncoming(state, key, message, isActive)
  local conversation = Store.EnsureConversation(state, key)
  table.insert(conversation.messages, message)
  MessageMetadata.Apply(state, key, conversation, message)
  MessageMetadata.Compact(message)
  StoreRetention.AfterAppend(state, key, conversation, message)

  if message.kind == "user" and message.direction == "in" then
    conversation.activeStatus = nil
  end

  if not isActive and shouldIncrementUnread(message) then
    conversation.unreadCount = conversation.unreadCount + 1
  end
end
function Store.RecordIncomingActivity(state, key, message, isActive)
  local conversation = Store.EnsureConversation(state, key)
  if MessageMetadata.IsLatest(message, conversation.lastActivityAt, conversation.lastActivityLineID) then
    MessageMetadata.ApplyActivity(conversation, message)
  end
  if MessageMetadata.IsIncomingUser(message) and MessageMetadata.IsLatest(message, conversation.lastIncomingAt, conversation.lastIncomingLineID) then
    MessageMetadata.ApplyIncoming(conversation, message)
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

  StoreRetention.AfterAppend(state, key, conversation, message)
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
    if StoreRetention.IsExpired(state, conversation, conversation.lastActivityAt, now) then
      StoreRetention.Remove(state, key, StoreRetention.REASON_RETENTION)
    end
    return state.conversations[key]
  end

  local updatesLatestActivity = isNewest and MessageMetadata.IsLatest(message, conversation.lastActivityAt, conversation.lastActivityLineID)
  local prospectiveLastActivityAt = conversation.lastActivityAt
  if updatesLatestActivity then
    prospectiveLastActivityAt = message.sentAt
  end
  local now = type(state.now) == "function" and state.now() or message.sentAt
  if StoreRetention.IsExpired(state, conversation, prospectiveLastActivityAt, now) then
    table.remove(messages, messageIndex)
    StoreRetention.Remove(state, key, StoreRetention.REASON_RETENTION)
    return nil
  end

  if isNewest then
    if updatesLatestActivity then
      MessageMetadata.ApplyActivity(conversation, message)
    end
    if
      MessageMetadata.IsIncomingUser(message) and MessageMetadata.IsLatest(message, conversation.lastIncomingAt, conversation.lastIncomingLineID)
    then
      MessageMetadata.ApplyIncoming(conversation, message)
    end
    MessageMetadata.ApplyContact(state, key, conversation, message)
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
  MessageMetadata.Compact(message)
  if not isActive and shouldIncrementUnread(message) then
    conversation.unreadCount = conversation.unreadCount + 1
  end
  return conversation
end

function Store.AppendOutgoing(state, key, message)
  local conversation = Store.EnsureConversation(state, key)
  -- Writing to someone accepts their message request.
  conversation.request = nil
  table.insert(conversation.messages, message)
  MessageMetadata.Apply(state, key, conversation, message)
  MessageMetadata.Compact(message)
  StoreRetention.AfterAppend(state, key, conversation, message)
end

function Store.SetActiveStatus(state, key, status)
  local conversation = Store.EnsureConversation(state, key)
  conversation.activeStatus = status
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
    if MessageMetadata.IsOutgoingUser(message) and message.delivery == nil then
      break
    end
    if MessageMetadata.IsIncomingUser(message) then
      count = count + 1
    end
  end
  return count
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
    StoreRetention.EvictOldest(state)
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
  return StoreRetention.Remove(state, key, StoreRetention.REASON_EXPLICIT)
end

function Store.SetSortOrder(state, key, order)
  local conversation = state.conversations[key]
  if conversation then
    conversation.sortOrder = order
  end
end

Store.ApplyRetention = StoreRetention.Apply
Store.ExpireAll = StoreRetention.ExpireAll

ns.ConversationStore = Store

return Store
