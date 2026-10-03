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

-- Entry count per conversation's entries table. Remember only adds, so a
-- busy chat is rebuilt from its retained messages once the count passes
-- max(MIN_REBUILD_AT, 2 x retained messages). Weak keys: a dropped entries
-- table takes its count with it.
local MIN_REBUILD_AT = 32
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
  return (entryCounts[entries] or 0) > math.max(MIN_REBUILD_AT, 2 * retained)
end

-- A remembered message is still in the conversation only while it is the
-- oldest retained row or newer than it; anything else was trimmed.
local function isRetained(message, conversation)
  local oldest = conversation.messages and conversation.messages[1]
  if oldest == nil then
    return false
  end
  return message == oldest or (tonumber(message.sentAt) or 0) > (tonumber(oldest.sentAt) or 0)
end

function DuplicateCollapse.Find(index, conversation, senderKey, normalized)
  local conversationKey = conversation and conversation.conversationKey
  if conversationKey == nil or senderKey == nil or normalized == nil then
    return nil
  end
  local entries = index[conversationKey]
  if entries == nil or isOverfull(entries, conversation) then
    entries = buildEntries(conversation)
    index[conversationKey] = entries
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
