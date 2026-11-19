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

local MessageMetadata = ns.ConversationStoreMessageMetadata or require("WhisperMessenger.Model.ConversationStore.MessageMetadata")

local ConversationMerge = {}

local function numericValue(value)
  return tonumber(value) or 0
end

local function newestConversation(canonical, legacy, timestampField, lineIDField)
  local canonicalTimestamp = numericValue(canonical[timestampField])
  local legacyTimestamp = numericValue(legacy[timestampField])
  if legacyTimestamp ~= canonicalTimestamp then
    return legacyTimestamp > canonicalTimestamp and legacy or canonical
  end
  if numericValue(legacy[lineIDField]) > numericValue(canonical[lineIDField]) then
    return legacy
  end
  return canonical
end

-- The record whose activity the merged chat keeps. Real activity takes over
-- from a status line that opened the other record, even when it is older,
-- the same rule as a real line stored into a status-opened chat. Runs before
-- the transcripts merge so the check reads each record's own lines.
local function latestActivityRecord(canonical, legacy)
  local canonicalStatusOnly = MessageMetadata.ActivityFromStatusLine(canonical)
  if canonicalStatusOnly ~= MessageMetadata.ActivityFromStatusLine(legacy) then
    local real = canonicalStatusOnly and legacy or canonical
    if numericValue(real.lastActivityAt) > 0 then
      return real
    end
  end
  return newestConversation(canonical, legacy, "lastActivityAt", "lastActivityLineID")
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

  -- Line counters restart each session, so an id alone can match two real
  -- lines; a true copy of one line also shares its time.
  local function append(messages)
    for _, message in ipairs(messages or {}) do
      local sentAt = type(message) == "table" and numericValue(message.sentAt) or 0
      local messageID = type(message) == "table" and message.id or nil
      local dedupeKey = messageID ~= nil and (tostring(messageID) .. "@" .. tostring(sentAt)) or nil
      if dedupeKey == nil or not seenIDs[dedupeKey] then
        if dedupeKey ~= nil then
          seenIDs[dedupeKey] = true
        end
        sequence = sequence + 1
        entries[#entries + 1] = {
          message = message,
          sentAt = sentAt,
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
  local canonicalActivityUnread = math.max(0, numericValue(canonical.unreadActivityCount))
  local legacyActivityUnread = math.max(0, numericValue(legacy.unreadActivityCount))
  local activityUnread = canonicalActivityUnread + legacyActivityUnread
  local messageUnread = math.max(0, numericValue(canonical.unreadCount) - canonicalActivityUnread)
    + math.max(0, numericValue(legacy.unreadCount) - legacyActivityUnread)
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
  canonical.unreadActivityCount = activityUnread
  canonical.unreadCount = math.min(messageUnread, maximumUnread) + activityUnread
end

-- The row preview is the merged thread's last line, which may be a status
-- line, unless the activity came from a newer line kept outside the thread.
-- At the same second a line with no ID (a status line) counts as the newer.
local function mergedPreview(messages, latestActivity)
  local lastLine = messages[#messages]
  if type(lastLine) ~= "table" then
    return latestActivity.lastPreview
  end
  local lineAt = numericValue(lastLine.sentAt)
  local activityAt = numericValue(latestActivity.lastActivityAt)
  local activityLineIsLater = lastLine.lineID ~= nil and numericValue(latestActivity.lastActivityLineID) > numericValue(lastLine.lineID)
  if activityAt > lineAt or (activityAt == lineAt and activityLineIsLater) then
    return latestActivity.lastPreview
  end
  return lastLine.text
end

local function mergeMetadata(canonical, legacy, latestActivity)
  canonical.pinned = canonical.pinned == true or legacy.pinned == true
  canonical.sortOrder = deliberateSortOrder(canonical) or deliberateSortOrder(legacy) or 0
  -- Player-set prefs: the canonical record wins, the legacy one fills gaps.
  canonical.muted = (canonical.muted == true or legacy.muted == true) or nil
  canonical.nickname = canonical.nickname or legacy.nickname
  canonical.note = canonical.note or legacy.note
  canonical.draft = canonical.draft or legacy.draft
  canonical.notifyOnline = (canonical.notifyOnline == true or legacy.notifyOnline == true) or nil
  local zoneWatch = canonical.notifyZone == true and canonical or legacy
  canonical.notifyZone = zoneWatch.notifyZone == true or nil
  canonical.notifyZoneFrom = canonical.notifyZone and zoneWatch.notifyZoneFrom or nil
  local lastSeenAt = math.max(numericValue(canonical.lastSeenAt), numericValue(legacy.lastSeenAt))
  canonical.lastSeenAt = lastSeenAt > 0 and lastSeenAt or nil
  -- A message request stays one only if both records were (fail open).
  canonical.request = (canonical.request == true and legacy.request == true) or nil

  -- The away status follows the newest record by time, status lines included,
  -- so it is picked before the activity fields are overwritten.
  local newestRecord = newestConversation(canonical, legacy, "lastActivityAt", "lastActivityLineID")
  canonical.lastActivityAt = latestActivity.lastActivityAt
  canonical.lastActivityLineID = latestActivity.lastActivityLineID
  canonical.lastPreview = mergedPreview(canonical.messages, latestActivity)

  local latestIncoming = newestConversation(canonical, legacy, "lastIncomingAt", "lastIncomingLineID")
  canonical.lastIncomingAt = latestIncoming.lastIncomingAt
  canonical.lastIncomingLineID = latestIncoming.lastIncomingLineID
  canonical.lastIncomingSender = latestIncoming.lastIncomingSender
  canonical.lastIncomingPreview = latestIncoming.lastIncomingPreview

  if newestRecord.activeStatus == nil or type(newestRecord.activeStatus) == "table" then
    canonical.activeStatus = newestRecord.activeStatus
  else
    local otherConversation = newestRecord == canonical and legacy or canonical
    canonical.activeStatus = type(otherConversation.activeStatus) == "table" and otherConversation.activeStatus or nil
  end
end

-- Rekeys one conversation into its canonical key. On collision, every persisted
-- invariant is merged into the canonical record and the old-to-new mapping is
-- returned for runtime selection/reply references.
function ConversationMerge.Rekey(conversations, oldKey, newKey, maxMessages, messageRetentionAt)
  if type(conversations) ~= "table" or oldKey == nil or newKey == nil or oldKey == newKey then
    return {}
  end

  local legacy = conversations[oldKey]
  if type(legacy) ~= "table" then
    return {}
  end
  if type(messageRetentionAt) == "table" then
    messageRetentionAt[oldKey] = nil
    messageRetentionAt[newKey] = nil
  end

  local canonical = conversations[newKey]
  if type(canonical) == "table" then
    local latestActivity = latestActivityRecord(canonical, legacy)
    mergeMessages(canonical, legacy, maxMessages)
    mergeUnreadCount(canonical, legacy)
    mergeMetadata(canonical, legacy, latestActivity)
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
