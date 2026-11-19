local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- "Separate <Character>": moves one character's lines out of the Battle.net
-- chat they were folded into, back into the character's own chat, and marks
-- the character so it never folds in again. Nickname, note, pin and draft
-- stay on the Battle.net chat.
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Retention = ns.Retention or require("WhisperMessenger.Model.Retention")
local MessageMetadata = ns.ConversationStoreMessageMetadata or require("WhisperMessenger.Model.ConversationStore.MessageMetadata")
local CharacterMergeMap = ns.CharacterMergeMap or require("WhisperMessenger.Model.CharacterMergeMap")

local CharacterSeparate = {}

local ipairs = ipairs
local CHARACTER_KEY_PREFIX = "wow::WOW::"

-- The fold stamped every line of the character with the map's name, so the
-- key built from it matches exactly; another realm's character never does.
local function isCharacterLine(message, characterKey)
  return type(message) == "table"
    and message.channel == "WOW"
    and type(message.playerName) == "string"
    and CHARACTER_KEY_PREFIX .. string.lower(message.playerName) == characterKey
end

-- How many of the chat's unread messages are the character's: its unread
-- count covers the newest incoming lines, activity unread aside.
local function movedUnreadCount(conversation, characterKey)
  local unread = math.max(0, (tonumber(conversation.unreadCount) or 0) - (tonumber(conversation.unreadActivityCount) or 0))
  local messages = conversation.messages or {}
  local moved = 0
  local index = #messages
  while unread > 0 and index >= 1 do
    local message = messages[index]
    if MessageMetadata.IsIncomingUser(message) then
      unread = unread - 1
      if isCharacterLine(message, characterKey) then
        moved = moved + 1
      end
    end
    index = index - 1
  end
  return moved
end

local function splitLines(conversation, characterKey)
  local kept, moved = {}, {}
  for _, message in ipairs(conversation.messages or {}) do
    if isCharacterLine(message, characterKey) then
      moved[#moved + 1] = message
    else
      kept[#kept + 1] = message
    end
  end
  return kept, moved
end

local function newestClassTag(messages)
  for index = #messages, 1, -1 do
    if messages[index].classTag ~= nil then
      return messages[index].classTag
    end
  end
  return nil
end

-- Stable by time: the chat's own lines come first on a tie.
local function mergeByTime(existing, moved)
  local entries = {}
  for _, list in ipairs({ existing, moved }) do
    for _, message in ipairs(list) do
      entries[#entries + 1] = { message = message, sentAt = tonumber(message.sentAt) or 0, sequence = #entries + 1 }
    end
  end
  table.sort(entries, function(left, right)
    if left.sentAt ~= right.sentAt then
      return left.sentAt < right.sentAt
    end
    return left.sequence < right.sequence
  end)
  local messages = {}
  for index, entry in ipairs(entries) do
    messages[index] = entry.message
  end
  return messages
end

local function newer(candidate, message)
  return candidate == nil or MessageMetadata.IsLatest(message, candidate.sentAt, candidate.lineID)
end

-- Preview from the newest line of any kind; activity from the newest real
-- line (a status line only when there is nothing else). A chat left with no
-- lines keeps its activity, so retention does not clear it early.
local function refreshSummary(conversation)
  local newest, newestReal, newestIncoming
  for _, message in ipairs(conversation.messages) do
    if newer(newest, message) then
      newest = message
    end
    if message.kind ~= "system" and newer(newestReal, message) then
      newestReal = message
    end
    if MessageMetadata.IsIncomingUser(message) and newer(newestIncoming, message) then
      newestIncoming = message
    end
  end
  conversation.lastPreview = newest and newest.text
  local activity = newestReal or newest
  if activity ~= nil then
    conversation.lastActivityAt = activity.sentAt
    conversation.lastActivityLineID = activity.lineID
  end
  conversation.lastIncomingAt = newestIncoming and newestIncoming.sentAt
  conversation.lastIncomingLineID = newestIncoming and newestIncoming.lineID
  conversation.lastIncomingSender = newestIncoming and newestIncoming.playerName
  conversation.lastIncomingPreview = newestIncoming and newestIncoming.text
end

-- Stored directly: EnsureConversation could evict the Battle.net chat.
local function receivingChat(store, characterKey, name, moved, movedUnread)
  local character = store.conversations[characterKey]
  if character == nil then
    character = Store.NewRecord(characterKey, Identity.FromWhisper(name, nil))
    character.messages = moved
    character.unreadCount = movedUnread
    character.classTag = newestClassTag(moved)
    store.conversations[characterKey] = character
    return character
  end
  character.messages = mergeByTime(character.messages or {}, moved)
  Retention.TrimMessages(character.messages, store.config and store.config.maxMessagesPerConversation)
  character.unreadCount = (tonumber(character.unreadCount) or 0) + movedUnread
  character.classTag = character.classTag or newestClassTag(moved)
  return character
end

function CharacterSeparate.Separate(store, merges, bnetKey, characterKey)
  local entry = CharacterMergeMap.Get(merges, characterKey)
  if entry == nil or entry.bnetKey ~= bnetKey then
    return nil
  end
  local friend = store.conversations[bnetKey]
  if type(friend) ~= "table" then
    CharacterMergeMap.MarkSeparated(merges, characterKey)
    return nil
  end
  local movedUnread = movedUnreadCount(friend, characterKey)
  local kept, moved = splitLines(friend, characterKey)
  CharacterMergeMap.MarkSeparated(merges, characterKey)
  if #moved == 0 then
    return nil
  end

  friend.messages = kept
  friend.unreadCount = (tonumber(friend.unreadCount) or 0) - movedUnread
  local character = receivingChat(store, characterKey, entry.name, moved, movedUnread)
  refreshSummary(friend)
  refreshSummary(character)
  if store.messageRetentionAt then
    store.messageRetentionAt[bnetKey] = nil
    store.messageRetentionAt[characterKey] = nil
  end

  return character
end

ns.CharacterSeparate = CharacterSeparate
return CharacterSeparate
