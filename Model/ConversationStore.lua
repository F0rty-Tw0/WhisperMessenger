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

function Store.New(config)
  return {
    config = config or {},
    conversations = {},
  }
end

local function ensureConversation(state, key)
  state.conversations[key] = state.conversations[key]
    or {
      messages = {},
      unreadCount = 0,
      lastPreview = nil,
      lastActivityAt = 0,
      guid = nil,
      bnetAccountID = nil,
      gameAccountName = nil,
      className = nil,
      classTag = nil,
      raceName = nil,
      raceTag = nil,
      factionName = nil,
    }

  return state.conversations[key]
end

local function applyRetention(state, conversation)
  Retention.TrimMessages(conversation.messages, state.config.maxMessagesPerConversation)
end

local function applyMessageMetadata(conversation, message)
  conversation.lastPreview = message.text
  conversation.lastActivityAt = message.sentAt
  conversation.displayName = message.playerName or conversation.displayName
  conversation.channel = message.channel or conversation.channel or "WOW"
  conversation.guid = message.guid or conversation.guid
  conversation.bnetAccountID = message.bnetAccountID or conversation.bnetAccountID
  conversation.gameAccountName = message.gameAccountName or conversation.gameAccountName
  conversation.className = message.className or conversation.className
  conversation.classTag = message.classTag or conversation.classTag
  conversation.raceName = message.raceName or conversation.raceName
  conversation.raceTag = message.raceTag or conversation.raceTag
  conversation.factionName = message.factionName or conversation.factionName
end

local function shouldIncrementUnread(message)
  return message ~= nil and message.kind == "user" and message.direction == "in"
end

function Store.AppendIncoming(state, key, message, isActive)
  local conversation = ensureConversation(state, key)
  table.insert(conversation.messages, message)
  applyRetention(state, conversation)
  applyMessageMetadata(conversation, message)

  if not isActive and shouldIncrementUnread(message) then
    conversation.unreadCount = conversation.unreadCount + 1
  end
end

function Store.AppendOutgoing(state, key, message)
  local conversation = ensureConversation(state, key)
  table.insert(conversation.messages, message)
  applyRetention(state, conversation)
  applyMessageMetadata(conversation, message)
end

function Store.MarkRead(state, key)
  local conversation = ensureConversation(state, key)
  conversation.unreadCount = 0
end

ns.ConversationStore = Store

return Store
