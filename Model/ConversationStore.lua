local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- stylua: ignore start
local StoreRetention = ns.ConversationStoreRetention or require("WhisperMessenger.Model.ConversationStore.StoreRetention")
local MessageMetadata = ns.ConversationStoreMessageMetadata or require("WhisperMessenger.Model.ConversationStore.MessageMetadata")
local ChronologicalInsert = ns.ConversationStoreChronologicalInsert or require("WhisperMessenger.Model.ConversationStore.ChronologicalInsert")
local NewRecord = ns.ConversationStoreNewRecord or require("WhisperMessenger.Model.ConversationStore.NewRecord")
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

-- A fresh, unstored record; the merge fold stores one directly so retention
-- cannot evict the chat it folds in.
Store.NewRecord = NewRecord.New

function Store.EnsureConversation(state, key, metadata)
  state.conversations = state.conversations or {}
  local conversation = state.conversations[key]
  if conversation ~= nil then
    return conversation, false
  end

  conversation = Store.NewRecord(key, metadata)
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
  MessageMetadata.Compact(message, conversation)
  StoreRetention.AfterAppend(state, key, conversation, message)

  if message.kind == "user" and message.direction == "in" then
    conversation.activeStatus = nil
  end

  if not isActive and shouldIncrementUnread(message) then
    conversation.unreadCount = conversation.unreadCount + 1
    if message.mention then
      conversation.hasUnreadMention = true
    end
  end
end
function Store.RecordIncomingActivity(state, key, message, isActive)
  local conversation = Store.EnsureConversation(state, key)
  -- The line is kept outside the transcript, so it is the newest line only
  -- when it is newer than the transcript's last one.
  local lastLine = conversation.messages[#conversation.messages]
  local isNewestLine = lastLine == nil or MessageMetadata.IsLatest(message, lastLine.sentAt, lastLine.lineID)
  MessageMetadata.ApplyMoves(conversation, message, MessageMetadata.Moves(conversation, message, isNewestLine))
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
  local sentAt = tonumber(message.sentAt) or 0
  local lineID = tonumber(message.lineID)
  local result, isNewest, kept, movesPreview, movesActivity = ChronologicalInsert.Insert(state, key, conversation, message)
  if not kept then
    return result
  end

  MessageMetadata.ApplyMoves(conversation, message, movesPreview, movesActivity)
  if isNewest or movesActivity then
    if
      MessageMetadata.IsIncomingUser(message) and MessageMetadata.IsLatest(message, conversation.lastIncomingAt, conversation.lastIncomingLineID)
    then
      MessageMetadata.ApplyIncoming(conversation, message)
    end
  end
  -- Contact data (names, realm, account) is current only on the newest line.
  if isNewest then
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
  MessageMetadata.Compact(message, conversation)
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
  MessageMetadata.Compact(message, conversation)
  StoreRetention.AfterAppend(state, key, conversation, message)
end

-- A status line such as "Left party": shown as the row preview and kept and
-- aged like any line, but it is not chat, so the conversation's last activity
-- (list order and the retention clock) stays on its last real message.
function Store.AppendNotice(state, key, message)
  local conversation = state.conversations[key]
  if conversation == nil then
    return nil
  end
  conversation.messages = conversation.messages or {}
  table.insert(conversation.messages, message)
  conversation.lastPreview = message.text
  StoreRetention.AfterAppend(state, key, conversation, message)
  return conversation
end

function Store.SetActiveStatus(state, key, status)
  local conversation = Store.EnsureConversation(state, key)
  conversation.activeStatus = status
end

function Store.MarkRead(state, key)
  local conversation = Store.EnsureConversation(state, key)
  conversation.unreadCount = 0
  conversation.unreadActivityCount = 0
  conversation.hasUnreadMention = nil
end

-- Whispers, groups and requests all live in state.conversations.
function Store.MarkAllRead(state)
  for key in pairs(state.conversations) do
    Store.MarkRead(state, key)
  end
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

-- Empties the store one conversation at a time, so each one leaves through
-- state.onConversationRemoved like any other explicit removal.
function Store.RemoveAll(state)
  for key in pairs(state.conversations) do
    Store.Remove(state, key)
  end
end

function Store.SetSortOrder(state, key, order)
  local conversation = state.conversations[key]
  if conversation then
    conversation.sortOrder = order
  end
end

Store.ApplyRetention = StoreRetention.Apply
Store.ExpireAll = StoreRetention.ExpireAll
function Store.InsertOutgoingChronological(state, key, message)
  return ChronologicalInsert.Outgoing(Store.EnsureConversation, state, key, message)
end
Store.CollapseRepeat = (ns.ConversationStoreRepeatCollapse or require("WhisperMessenger.Model.ConversationStore.RepeatCollapse")).CollapseRepeat

ns.ConversationStore = Store

return Store
