local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- How a stored message updates its conversation record: activity and
-- last-incoming fields, contact metadata, and per-message compaction.
local MessageMetadata = {}

function MessageMetadata.Compact(message)
  message.eventName = nil
  message.className = nil
  message.raceName = nil
  message.raceTag = nil
  message.factionName = nil
end

function MessageMetadata.IsIncomingUser(message)
  return message ~= nil and message.kind == "user" and message.direction == "in"
end

function MessageMetadata.IsOutgoingUser(message)
  return message ~= nil and message.kind == "user" and message.direction == "out"
end

function MessageMetadata.ApplyActivity(conversation, message)
  conversation.lastPreview = message.text
  conversation.lastActivityAt = message.sentAt
  conversation.lastActivityLineID = message.lineID
end

function MessageMetadata.ApplyIncoming(conversation, message)
  conversation.lastIncomingSender = message.playerName or conversation.lastIncomingSender
  conversation.lastIncomingPreview = message.text
  conversation.lastIncomingAt = message.sentAt
  conversation.lastIncomingLineID = message.lineID
end

function MessageMetadata.ApplyContact(state, key, conversation, message)
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

function MessageMetadata.Apply(state, key, conversation, message)
  MessageMetadata.ApplyActivity(conversation, message)
  if MessageMetadata.IsIncomingUser(message) then
    MessageMetadata.ApplyIncoming(conversation, message)
  end
  MessageMetadata.ApplyContact(state, key, conversation, message)
end

function MessageMetadata.IsLatest(message, latestAt, latestLineID)
  local sentAt = tonumber(message.sentAt) or 0
  local latestSentAt = tonumber(latestAt) or 0
  if sentAt ~= latestSentAt then
    return sentAt > latestSentAt
  end

  local lineID = tonumber(message.lineID)
  local latestLineIDNumber = tonumber(latestLineID)
  return lineID == nil or latestLineIDNumber == nil or lineID >= latestLineIDNumber
end

ns.ConversationStoreMessageMetadata = MessageMetadata
return MessageMetadata
