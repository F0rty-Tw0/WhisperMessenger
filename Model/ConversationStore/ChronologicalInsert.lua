local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- stylua: ignore start
local StoreRetention = ns.ConversationStoreRetention or require("WhisperMessenger.Model.ConversationStore.StoreRetention")
local MessageMetadata = ns.ConversationStoreMessageMetadata or require("WhisperMessenger.Model.ConversationStore.MessageMetadata")
-- stylua: ignore end

-- Inserting a message at its real time instead of appending it, for messages
-- that arrive after newer ones (replayed or backfilled lines).
local ChronologicalInsert = {}

-- Index where a message sent at sentAt (tie-broken by lineID) belongs, and
-- whether that is the end of the transcript.
function ChronologicalInsert.FindIndex(messages, sentAt, lineID)
  sentAt = tonumber(sentAt) or 0
  lineID = tonumber(lineID)
  local insertAt = #messages + 1
  for index, existing in ipairs(messages) do
    local existingSentAt = tonumber(existing.sentAt) or 0
    local existingLineID = tonumber(existing.lineID)
    if existingSentAt > sentAt or (existingSentAt == sentAt and lineID and existingLineID and existingLineID > lineID) then
      insertAt = index
      break
    end
  end
  return insertAt, insertAt == #messages + 1
end

local function indexOf(messages, message)
  for index, candidate in ipairs(messages) do
    if candidate == message then
      return index
    end
  end
  return nil
end

local function currentTime(state, message)
  return type(state.now) == "function" and state.now() or message.sentAt
end

-- The player's own message, inserted at its real time. An older message never
-- rolls the preview or list order back past a newer one; unread is untouched.
-- Also returns whether it landed at the end of the transcript.
function ChronologicalInsert.Outgoing(ensureConversation, state, key, message)
  local conversation = ensureConversation(state, key)
  -- Writing to someone accepts their message request.
  conversation.request = nil
  local messages = conversation.messages
  local insertAt, isNewest = ChronologicalInsert.FindIndex(messages, message.sentAt, message.lineID)
  table.insert(messages, insertAt, message)

  StoreRetention.AfterAppend(state, key, conversation, message)
  local storedConversation = state.conversations[key]
  if storedConversation ~= conversation then
    return storedConversation, isNewest
  end

  local messageIndex = indexOf(conversation.messages, message)
  if messageIndex == nil then
    if StoreRetention.IsExpired(state, conversation, conversation.lastActivityAt, currentTime(state, message)) then
      StoreRetention.Remove(state, key, StoreRetention.REASON_RETENTION)
    end
    return state.conversations[key], isNewest
  end

  local updatesLatestActivity = isNewest and MessageMetadata.IsLatest(message, conversation.lastActivityAt, conversation.lastActivityLineID)
  local prospectiveLastActivityAt = conversation.lastActivityAt
  if updatesLatestActivity then
    prospectiveLastActivityAt = message.sentAt
  end
  if StoreRetention.IsExpired(state, conversation, prospectiveLastActivityAt, currentTime(state, message)) then
    table.remove(messages, messageIndex)
    StoreRetention.Remove(state, key, StoreRetention.REASON_RETENTION)
    return nil, isNewest
  end

  if updatesLatestActivity then
    MessageMetadata.ApplyActivity(conversation, message)
    MessageMetadata.ApplyContact(state, key, conversation, message)
  end
  MessageMetadata.Compact(message)
  return conversation, isNewest
end

ns.ConversationStoreChronologicalInsert = ChronologicalInsert
return ChronologicalInsert
