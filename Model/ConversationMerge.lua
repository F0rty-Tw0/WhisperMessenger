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

local ConversationMerge = {}

local function numericValue(value)
  if type(value) == "number" then
    return value
  end
  return 0
end

local function newestConversation(canonical, legacy, field)
  if numericValue(legacy[field]) > numericValue(canonical[field]) then
    return legacy
  end
  return canonical
end

local function deliberateSortOrder(conversation)
  local sortOrder = conversation.sortOrder
  if type(sortOrder) == "number" and sortOrder ~= 0 then
    return sortOrder
  end
  return nil
end

local function isIncomingUserMessage(message)
  return type(message) == "table" and message.kind == "user" and message.direction == "in"
end

local function mergeMessages(canonical, legacy, maxMessages)
  local entries = {}
  local seenIDs = {}
  local sequence = 0

  local function append(messages)
    for _, message in ipairs(messages or {}) do
      local messageID = type(message) == "table" and message.id or nil
      if messageID == nil or not seenIDs[messageID] then
        if messageID ~= nil then
          seenIDs[messageID] = true
        end
        sequence = sequence + 1
        entries[#entries + 1] = {
          message = message,
          sentAt = type(message) == "table" and numericValue(message.sentAt) or 0,
          sequence = sequence,
        }
      end
    end
  end

  -- Canonical history wins equal timestamps and duplicate stable IDs.
  append(canonical.messages)
  append(legacy.messages)
  table.sort(entries, function(left, right)
    if left.sentAt ~= right.sentAt then
      return left.sentAt < right.sentAt
    end
    return left.sequence < right.sequence
  end)

  local messages = canonical.messages or {}
  local previousCount = #messages
  for index, entry in ipairs(entries) do
    messages[index] = entry.message
  end
  for index = #entries + 1, previousCount do
    messages[index] = nil
  end
  canonical.messages = messages
  Retention.TrimMessages(messages, maxMessages)
end

local function mergeUnreadCount(canonical, legacy)
  local unreadCount = math.max(0, numericValue(canonical.unreadCount)) + math.max(0, numericValue(legacy.unreadCount))
  local maximumUnread = #canonical.messages
  local messagesAreClassified = true
  local incomingCount = 0

  for _, message in ipairs(canonical.messages) do
    if type(message) ~= "table" or message.kind == nil or message.direction == nil then
      messagesAreClassified = false
    elseif isIncomingUserMessage(message) then
      incomingCount = incomingCount + 1
    end
  end

  if messagesAreClassified then
    maximumUnread = incomingCount
  end
  canonical.unreadCount = math.min(unreadCount, maximumUnread)
end

local function mergeMetadata(canonical, legacy)
  canonical.pinned = canonical.pinned == true or legacy.pinned == true
  canonical.sortOrder = deliberateSortOrder(canonical) or deliberateSortOrder(legacy) or 0

  local latestActivity = newestConversation(canonical, legacy, "lastActivityAt")
  canonical.lastActivityAt = latestActivity.lastActivityAt
  canonical.lastPreview = latestActivity.lastPreview

  local latestIncoming = newestConversation(canonical, legacy, "lastIncomingAt")
  canonical.lastIncomingAt = latestIncoming.lastIncomingAt
  canonical.lastIncomingSender = latestIncoming.lastIncomingSender
  canonical.lastIncomingPreview = latestIncoming.lastIncomingPreview

  if latestActivity.activeStatus == nil or type(latestActivity.activeStatus) == "table" then
    canonical.activeStatus = latestActivity.activeStatus
  else
    local otherConversation = latestActivity == canonical and legacy or canonical
    canonical.activeStatus = type(otherConversation.activeStatus) == "table" and otherConversation.activeStatus or nil
  end
end

-- Rekeys one conversation into its canonical key. On collision, every persisted
-- invariant is merged into the canonical record and the old-to-new mapping is
-- returned for runtime selection/reply references.
function ConversationMerge.Rekey(conversations, oldKey, newKey, maxMessages)
  if type(conversations) ~= "table" or oldKey == nil or newKey == nil or oldKey == newKey then
    return {}
  end

  local legacy = conversations[oldKey]
  if type(legacy) ~= "table" then
    return {}
  end

  local canonical = conversations[newKey]
  if type(canonical) == "table" then
    mergeMessages(canonical, legacy, maxMessages)
    mergeUnreadCount(canonical, legacy)
    mergeMetadata(canonical, legacy)
  else
    canonical = legacy
  end

  canonical.conversationKey = newKey
  conversations[newKey] = canonical
  conversations[oldKey] = nil
  return { [oldKey] = newKey }
end

ns.ConversationMerge = ConversationMerge
return ConversationMerge
