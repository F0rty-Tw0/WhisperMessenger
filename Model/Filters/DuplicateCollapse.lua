local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")

-- Duplicate collapse: a sender repeating the same (normalized) line counts
-- up on the existing row instead of adding a new one. The index is
-- runtime-only and never saved:
--   index[conversationKey][senderKey .. "\0" .. normalized] = message
local DuplicateCollapse = {}

local gsub = string.gsub
local lower = string.lower
local ipairs = ipairs
local pairs = pairs

-- Entry count per conversation's entries table. Remember only adds, so a
-- busy chat drops entries for trimmed messages once the count passes
-- max(MIN_PRUNE_AT, 2 x retained messages). Weak keys: a dropped entries
-- table takes its count with it.
local MIN_PRUNE_AT = 32
local entryCounts = setmetatable({}, { __mode = "k" })

-- Same sender key as the ignore list: lowercased short name, nil for secrets.
DuplicateCollapse.SenderKey = IgnoreList.Key

-- Drops colors, link wrappers, raid icons, case, whitespace and punctuation.
function DuplicateCollapse.NormalizeText(text)
  text = gsub(text, "|c%x%x%x%x%x%x%x%x", "")
  text = gsub(text, "|r", "")
  text = gsub(text, "|H.-|h(.-)|h", "%1")
  text = gsub(text, "{.-}", "")
  text = gsub(lower(text), "[%p%s]+", " ")
  text = gsub(text, "^ ", "")
  text = gsub(text, " $", "")
  return text
end

local function entryKey(senderKey, normalized)
  return senderKey .. "\0" .. normalized
end

-- Rebuilt once per session from the stored messages (incoming user lines),
-- so a repeat after /reload still finds the row saved before it.
local function buildEntries(conversation)
  local entries = {}
  local count = 0
  for _, message in ipairs(conversation.messages or {}) do
    if message.kind == "user" and message.direction == "in" and type(message.text) == "string" then
      local senderKey = DuplicateCollapse.SenderKey(message.playerName)
      if senderKey ~= nil then
        local key = entryKey(senderKey, DuplicateCollapse.NormalizeText(message.text))
        if entries[key] == nil then
          count = count + 1
        end
        entries[key] = message
      end
    end
  end
  entryCounts[entries] = count
  return entries
end

local function isOverfull(entries, conversation)
  local retained = conversation.messages and #conversation.messages or 0
  return (entryCounts[entries] or 0) > math.max(MIN_PRUNE_AT, 2 * retained)
end

-- A remembered message is still in the conversation while it is newer than
-- the oldest retained row. One from that row's second is retained only if
-- it is among the rows of that second; a trimmed one from it is not.
local function isRetained(message, conversation)
  local messages = conversation.messages
  local oldest = messages and messages[1]
  if oldest == nil then
    return false
  end
  local sentAt = tonumber(message.sentAt) or 0
  local oldestAt = tonumber(oldest.sentAt) or 0
  if sentAt ~= oldestAt then
    return sentAt > oldestAt
  end
  for _, row in ipairs(messages) do
    if row == message then
      return true
    end
    if (tonumber(row.sentAt) or 0) ~= oldestAt then
      return false
    end
  end
  return false
end

-- Drops entries whose message was trimmed. Reads only the stored keys, so
-- nothing is normalized again.
local function prune(entries, conversation)
  local count = 0
  for key, message in pairs(entries) do
    if isRetained(message, conversation) then
      count = count + 1
    else
      entries[key] = nil
    end
  end
  entryCounts[entries] = count
end

function DuplicateCollapse.Find(index, conversation, senderKey, normalized)
  local conversationKey = conversation and conversation.conversationKey
  if conversationKey == nil or senderKey == nil or normalized == nil then
    return nil
  end
  local entries = index[conversationKey]
  if entries == nil then
    entries = buildEntries(conversation)
    index[conversationKey] = entries
  elseif isOverfull(entries, conversation) then
    prune(entries, conversation)
  end
  local message = entries[entryKey(senderKey, normalized)]
  if message == nil or not isRetained(message, conversation) then
    return nil
  end
  return message
end

function DuplicateCollapse.Remember(index, conversationKey, senderKey, normalized, message)
  if conversationKey == nil or senderKey == nil or normalized == nil then
    return
  end
  local entries = index[conversationKey]
  if entries == nil then
    entries = {}
    index[conversationKey] = entries
  end
  local key = entryKey(senderKey, normalized)
  if entries[key] == nil then
    entryCounts[entries] = (entryCounts[entries] or 0) + 1
  end
  entries[key] = message
end

ns.DuplicateCollapse = DuplicateCollapse
return DuplicateCollapse
