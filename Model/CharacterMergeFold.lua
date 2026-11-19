local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Folds a friend's character chat into their Battle.net chat: the character's
-- lines move over stamped as character lines and the merge is recorded.
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local ConversationMerge = ns.ConversationMerge or require("WhisperMessenger.Model.ConversationMerge")
local CharacterMergeMap = ns.CharacterMergeMap or require("WhisperMessenger.Model.CharacterMergeMap")

local CharacterMergeFold = {}

local ipairs = ipairs

local IDENTITY_FIELDS = {
  "channel",
  "displayName",
  "guid",
  "bnetAccountID",
  "battleTag",
  "gameAccountName",
  "className",
  "classTag",
  "raceName",
  "raceTag",
  "factionName",
}

local function identityOf(contact)
  local fields = {}
  for _, field in ipairs(IDENTITY_FIELDS) do
    fields[field] = contact[field]
  end
  return fields
end

-- Written straight into the store: EnsureConversation could evict the
-- character chat that is about to move into this record.
local function newBnetRecord(store, bnetKey, contact)
  local record = identityOf(contact)
  record.conversationKey = bnetKey
  record.messages = {}
  record.unreadCount = 0
  record.unreadActivityCount = 0
  record.lastActivityAt = 0
  store.conversations[bnetKey] = record
end

local function stampLines(characterChat, name)
  for _, line in ipairs(characterChat.messages or {}) do
    if type(line) == "table" and (line.kind == "user" or line.kind == "system") then
      line.channel = "WOW"
      line.playerName = name
      if line.kind == "user" and line.direction == "in" and line.classTag == nil then
        line.classTag = characterChat.classTag
      end
    end
  end
end

function CharacterMergeFold.Fold(store, merges, characterKey, bnetKey, bnetContact, name, maxMessages)
  store.conversations = store.conversations or {}
  local characterChat = store.conversations[characterKey]
  if store.conversations[bnetKey] == nil then
    if bnetContact == nil then
      return nil
    end
    if characterChat == nil then
      Store.EnsureConversation(store, bnetKey, identityOf(bnetContact))
    else
      newBnetRecord(store, bnetKey, bnetContact)
    end
  end
  if characterChat ~= nil then
    stampLines(characterChat, name)
    ConversationMerge.Rekey(store.conversations, characterKey, bnetKey, maxMessages, store.messageRetentionAt)
  end
  CharacterMergeMap.Record(merges, characterKey, bnetKey, name)
  return store.conversations[bnetKey]
end

ns.CharacterMergeFold = CharacterMergeFold
return CharacterMergeFold
