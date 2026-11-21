local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The shape of a new ConversationStore record.
local NewRecord = {}

local ipairs = ipairs

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

-- A fresh conversation record carrying metadata's known fields. It is not
-- stored: the caller stores it.
function NewRecord.New(key, metadata)
  local conversation = newConversation(key)
  if type(metadata) == "table" then
    for _, field in ipairs(CONVERSATION_METADATA_FIELDS) do
      if metadata[field] ~= nil then
        conversation[field] = metadata[field]
      end
    end
  end

  return conversation
end

ns.ConversationStoreNewRecord = NewRecord
return NewRecord
