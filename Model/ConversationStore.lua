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
  state.conversations[key] = state.conversations[key] or {
    messages = {},
    unreadCount = 0,
    lastPreview = nil,
    lastActivityAt = 0,
  }

  return state.conversations[key]
end

local function applyRetention(state, conversation)
  Retention.TrimMessages(conversation.messages, state.config.maxMessagesPerConversation)
end

function Store.AppendIncoming(state, key, message, isActive)
  local conversation = ensureConversation(state, key)
  table.insert(conversation.messages, message)
  applyRetention(state, conversation)
  conversation.lastPreview = message.text
  conversation.lastActivityAt = message.sentAt
  conversation.displayName = message.playerName or conversation.displayName
  conversation.channel = message.channel or conversation.channel or "WOW"

  if not isActive and message.kind == "user" then
    conversation.unreadCount = conversation.unreadCount + 1
  end
end

function Store.AppendOutgoing(state, key, message)
  local conversation = ensureConversation(state, key)
  table.insert(conversation.messages, message)
  applyRetention(state, conversation)
  conversation.lastPreview = message.text
  conversation.lastActivityAt = message.sentAt
  conversation.displayName = message.playerName or conversation.displayName
  conversation.channel = message.channel or conversation.channel or "WOW"
end

function Store.MarkRead(state, key)
  local conversation = ensureConversation(state, key)
  conversation.unreadCount = 0
end

ns.ConversationStore = Store

return Store
