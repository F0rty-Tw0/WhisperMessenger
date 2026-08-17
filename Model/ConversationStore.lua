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

local function newConversation(key)
  return {
    messages = {},
    unreadCount = 0,
    lastPreview = nil,
    lastActivityAt = 0,
    lastIncomingSender = nil,
    lastIncomingPreview = nil,
    lastIncomingAt = nil,
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

local function evictOldestConversation(state, protectedKey)
  local maxConversations = state.config and state.config.maxConversations
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
    -- Pinned conversations are exempt from every retention path. The key
    -- currently being appended is also protected so all-pinned histories
    -- soft-overflow instead of dropping the new message.
    if key ~= protectedKey and conv.pinned ~= true then
      local activity = conv.lastActivityAt or 0
      if activity < oldestTime or (activity == oldestTime and (oldestKey == nil or key < oldestKey)) then
        oldestTime = activity
        oldestKey = key
      end
    end
  end

  if oldestKey then
    state.conversations[oldestKey] = nil
    return oldestKey
  end
  return nil
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

function Store.EnsureConversation(state, key, metadata)
  state.conversations = state.conversations or {}
  local conversation = state.conversations[key]
  if conversation ~= nil then
    return conversation, false
  end

  conversation = newConversation(key)
  if type(metadata) == "table" then
    for _, field in ipairs(CONVERSATION_METADATA_FIELDS) do
      if metadata[field] ~= nil then
        conversation[field] = metadata[field]
      end
    end
  end
  state.conversations[key] = conversation
  evictOldestConversation(state, key)
  return conversation, true
end

local function applyMessageCap(state, conversation)
  Retention.TrimMessages(conversation.messages, state.config.maxMessagesPerConversation)
end

local function isIncomingUserMessage(message)
  return message ~= nil and message.kind == "user" and message.direction == "in"
end

local function isOutgoingUserMessage(message)
  return message ~= nil and message.kind == "user" and message.direction == "out"
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
  if isIncomingUserMessage(message) then
    conversation.lastIncomingSender = message.playerName or conversation.lastIncomingSender
    conversation.lastIncomingPreview = message.text
    conversation.lastIncomingAt = message.sentAt
  end
end

local function shouldIncrementUnread(message)
  return isIncomingUserMessage(message)
end

function Store.AppendIncoming(state, key, message, isActive)
  local conversation = Store.EnsureConversation(state, key)
  table.insert(conversation.messages, message)
  applyMessageCap(state, conversation)
  applyMessageMetadata(conversation, message)

  if message.kind == "user" and message.direction == "in" then
    conversation.activeStatus = nil
  end

  if not isActive and shouldIncrementUnread(message) then
    conversation.unreadCount = conversation.unreadCount + 1
  end
end

function Store.AppendOutgoing(state, key, message)
  local conversation = Store.EnsureConversation(state, key)
  table.insert(conversation.messages, message)
  applyMessageCap(state, conversation)
  applyMessageMetadata(conversation, message)
end

function Store.SetActiveStatus(state, key, status)
  local conversation = Store.EnsureConversation(state, key)
  conversation.activeStatus = status
end

function Store.ClearActiveStatus(state, key)
  local conversation = state.conversations[key]
  if conversation then
    conversation.activeStatus = nil
  end
end

function Store.MarkRead(state, key)
  local conversation = Store.EnsureConversation(state, key)
  conversation.unreadCount = 0
end

function Store.CountUnansweredIncoming(conversation)
  if type(conversation) ~= "table" then
    return 0
  end

  local count = 0
  local messages = conversation.messages or {}
  for index = #messages, 1, -1 do
    local message = messages[index]
    if isOutgoingUserMessage(message) and message.delivery ~= "blocked" then
      break
    end
    if isIncomingUserMessage(message) then
      count = count + 1
    end
  end
  return count
end

function Store.ApplyRetention(state, now, protectedKey)
  state.conversations = state.conversations or {}
  local removed = {}

  for key, conversation in pairs(state.conversations) do
    if not conversation.pinned and Retention.IsExpired(conversation.lastActivityAt, state.config.conversationMaxAge, now) then
      state.conversations[key] = nil
      removed[key] = true
    else
      local messages = conversation.messages
      if messages then
        Retention.TrimMessages(messages, state.config.maxMessagesPerConversation)
        if not conversation.pinned then
          Retention.ExpireMessages(messages, state.config.messageMaxAge, now)
        end
      end
    end
  end

  while true do
    local key = evictOldestConversation(state, protectedKey)
    if key == nil then
      break
    end
    removed[key] = true
  end

  return removed
end
function Store.MarkUnread(state, key)
  local conversation = Store.EnsureConversation(state, key)
  conversation.unreadCount = Store.CountUnansweredIncoming(conversation)
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
    Store.ExpireAll(state)
    evictOldestConversation(state)
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
    if not conv.pinned and conv.messages then
      Retention.ExpireMessages(conv.messages, state.config.messageMaxAge, now)
    end
  end
end

ns.ConversationStore = Store

return Store
