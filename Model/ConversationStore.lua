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
      battleTag = nil,
      gameAccountName = nil,
      className = nil,
      classTag = nil,
      raceName = nil,
      raceTag = nil,
      factionName = nil,
    }

  return state.conversations[key]
end

local function evictOldestConversation(state)
  local maxConversations = state.config.maxConversations
  if type(maxConversations) ~= "number" or maxConversations < 1 then
    return
  end

  local count = 0
  for _ in pairs(state.conversations) do
    count = count + 1
  end

  if count <= maxConversations then
    return
  end

  local oldestKey = nil
  local oldestTime = math.huge
  for key, conv in pairs(state.conversations) do
    local activity = conv.lastActivityAt or 0
    if activity < oldestTime then
      oldestTime = activity
      oldestKey = key
    end
  end

  if oldestKey then
    state.conversations[oldestKey] = nil
  end
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
  conversation.battleTag = message.battleTag or conversation.battleTag
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
  evictOldestConversation(state)

  if message.kind == "user" and message.direction == "in" then
    conversation.activeStatus = nil
  end

  if not isActive and shouldIncrementUnread(message) then
    conversation.unreadCount = conversation.unreadCount + 1
  end
end

function Store.AppendOutgoing(state, key, message)
  local conversation = ensureConversation(state, key)
  table.insert(conversation.messages, message)
  applyRetention(state, conversation)
  applyMessageMetadata(conversation, message)
  evictOldestConversation(state)
end

function Store.SetActiveStatus(state, key, status)
  local conversation = ensureConversation(state, key)
  conversation.activeStatus = status
end

function Store.ClearActiveStatus(state, key)
  local conversation = state.conversations[key]
  if conversation then
    conversation.activeStatus = nil
  end
end

function Store.MarkRead(state, key)
  local conversation = ensureConversation(state, key)
  conversation.unreadCount = 0
end

function Store.Pin(state, key)
  local conversation = state.conversations[key]
  if conversation then
    conversation.pinned = true
  end
end

function Store.Unpin(state, key)
  local conversation = state.conversations[key]
  if conversation then
    conversation.pinned = false
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
  state.conversations[key] = nil
end

function Store.SetSortOrder(state, key, order)
  local conversation = state.conversations[key]
  if conversation then
    conversation.sortOrder = order
  end
end

function Store.SwapOrder(state, keyA, keyB)
  local a = state.conversations[keyA]
  local b = state.conversations[keyB]
  if a and b then
    local tmp = a.sortOrder or 0
    a.sortOrder = b.sortOrder or 0
    b.sortOrder = tmp
  end
end

function Store.ExpireAll(state, now)
  Retention.ExpireConversations(state.conversations, state.config.conversationMaxAge, now)
  for _, conv in pairs(state.conversations) do
    Retention.ExpireMessages(conv.messages, state.config.messageMaxAge, now)
  end
end

ns.ConversationStore = Store

return Store
