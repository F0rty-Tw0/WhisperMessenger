local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- How a stored message updates its conversation record: activity and
-- last-incoming fields, contact metadata, and per-message compaction.
local MessageMetadata = {}

local WHISPER_CHANNELS = { WOW = true, BN = true }

-- A character's line kept in its Battle.net friend's chat keeps what marks it
-- as the character's, and leaves the chat's identity alone so replies still
-- go out over Battle.net.
local function isCharacterLineInBnetChat(conversation, message)
  return conversation ~= nil and conversation.channel == "BN" and message.channel == "WOW"
end

-- Drops what the conversation already holds and nothing reads off the line.
-- Group and channel lines keep each sender's identity, and an unsent record
-- keeps what a resend needs. Older versions read none of the dropped fields
-- off a whisper line (they use the selected contact), so they show it the same.
function MessageMetadata.Compact(message, conversation)
  message.eventName = nil
  message.className = nil
  message.raceName = nil
  message.raceTag = nil
  message.factionName = nil
  if message.isCensored ~= true then
    message.isCensored = nil
  end
  if not WHISPER_CHANNELS[message.channel] or message.delivery ~= nil then
    return
  end
  message.guid = nil
  message.bnetAccountID = nil
  message.battleTag = nil
  message.gameAccountName = nil
  if isCharacterLineInBnetChat(conversation, message) then
    return
  end
  if message.direction == "out" then
    -- The recipient and channel are the conversation's; a sent line shows
    -- only the character that sent it.
    message.playerName = nil
    message.classTag = nil
    message.channel = nil
  elseif message.channel == "WOW" and conversation ~= nil and message.classTag == conversation.classTag then
    -- A character keeps its class; a Battle.net friend switches characters,
    -- so those lines keep theirs.
    message.classTag = nil
  end
end

-- A character conversation whose class changes (the name now belongs to a
-- new character) first gives the old class to the lines that left it off.
local function keepEarlierClass(conversation, newClassTag)
  local oldClassTag = conversation.classTag
  if conversation.channel ~= "WOW" or oldClassTag == nil or newClassTag == nil or newClassTag == oldClassTag then
    return
  end
  for _, line in ipairs(conversation.messages or {}) do
    if line.direction == "in" and line.kind == "user" and line.classTag == nil then
      line.classTag = oldClassTag
    end
  end
end

function MessageMetadata.IsIncomingUser(message)
  return message ~= nil and message.kind == "user" and message.direction == "in"
end

function MessageMetadata.IsOutgoingUser(message)
  return message ~= nil and message.kind == "user" and message.direction == "out"
end

-- Only real chat is activity. A status line ("player is offline", a zone
-- divider) leaves list order and the retention clock on the last real
-- message, except in a chat with no activity yet, which must still age out.
function MessageMetadata.MovesActivity(conversation, message)
  return message.kind ~= "system" or (tonumber(conversation.lastActivityAt) or 0) == 0
end

-- Whether the chat's activity is only the time a status line set when it
-- opened the chat: the transcript lines at that time and ID are all status
-- lines. Activity taken from a line kept outside the transcript matches none.
function MessageMetadata.ActivityFromStatusLine(conversation)
  local activityAt = tonumber(conversation.lastActivityAt)
  local activityLineID = tonumber(conversation.lastActivityLineID)
  local found = false
  for _, line in ipairs(conversation.messages or {}) do
    if type(line) == "table" and tonumber(line.sentAt) == activityAt and tonumber(line.lineID) == activityLineID then
      if line.kind ~= "system" then
        return false
      end
      found = true
    end
  end
  return found
end

-- What a line that is not simply appended moves, as (movesPreview,
-- movesActivity). The preview shows the newest line of any kind: isNewestLine
-- says it is the newest in the transcript, and it must also be newer than the
-- last activity, which can come from a line kept outside the transcript.
-- Activity follows the newest real line wherever it sits in the transcript,
-- so a real line arriving behind a newer status line still moves it, and the
-- first real line takes over from a status line that opened the chat even
-- when it is older than that line.
function MessageMetadata.Moves(conversation, message, isNewestLine)
  local newerThanActivity = MessageMetadata.IsLatest(message, conversation.lastActivityAt, conversation.lastActivityLineID)
  local movesActivity = MessageMetadata.MovesActivity(conversation, message)
    and (newerThanActivity or MessageMetadata.ActivityFromStatusLine(conversation))
  return isNewestLine and newerThanActivity, movesActivity
end

function MessageMetadata.ApplyMoves(conversation, message, movesPreview, movesActivity)
  if movesPreview then
    conversation.lastPreview = message.text
  end
  if movesActivity then
    conversation.lastActivityAt = message.sentAt
    conversation.lastActivityLineID = message.lineID
  end
end

-- For a line appended to the end of the transcript.
function MessageMetadata.ApplyActivity(conversation, message)
  MessageMetadata.ApplyMoves(conversation, message, true, MessageMetadata.MovesActivity(conversation, message))
end

function MessageMetadata.ApplyIncoming(conversation, message)
  conversation.lastIncomingSender = message.playerName or conversation.lastIncomingSender
  conversation.lastIncomingPreview = message.text
  conversation.lastIncomingAt = message.sentAt
  conversation.lastIncomingLineID = message.lineID
end

function MessageMetadata.ApplyContact(state, key, conversation, message)
  if isCharacterLineInBnetChat(conversation, message) then
    return
  end
  local oldGuid = conversation.guid
  -- A channel chat is titled after the channel and never takes on its last
  -- sender's identity (name, guid, class, race, faction).
  if conversation.channel ~= "CHANNEL" and message.channel ~= "CHANNEL" then
    conversation.displayName = message.playerName or conversation.displayName
    conversation.guid = message.guid or conversation.guid
    conversation.className = message.className or conversation.className
    keepEarlierClass(conversation, message.classTag)
    conversation.classTag = message.classTag or conversation.classTag
    conversation.raceName = message.raceName or conversation.raceName
    conversation.raceTag = message.raceTag or conversation.raceTag
    conversation.factionName = message.factionName or conversation.factionName
  end
  conversation.channel = message.channel or conversation.channel or "WOW"
  conversation.bnetAccountID = message.bnetAccountID or conversation.bnetAccountID
  conversation.battleTag = message.battleTag or conversation.battleTag
  conversation.gameAccountName = message.gameAccountName or conversation.gameAccountName

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
