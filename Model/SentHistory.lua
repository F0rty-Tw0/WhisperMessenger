local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")
local MessageMetadata = ns.ConversationStoreMessageMetadata or require("WhisperMessenger.Model.ConversationStore.MessageMetadata")

-- Lines the player sent, newest first, across every saved chat and every
-- character. Queued and failed lines count too, so they can be sent again.
local SentHistory = {}

SentHistory.MAX_ENTRIES = 50

-- The secret check comes first: a secret value raises on any comparison.
local function usableText(text, fits)
  if SecretValue.Is(text) or type(text) ~= "string" or text == "" then
    return false
  end
  return fits == nil or fits(text)
end

local function collect(conversations, fits)
  local entries = {}
  for key, conversation in pairs(conversations) do
    if type(conversation) == "table" and type(conversation.messages) == "table" then
      for index, message in ipairs(conversation.messages) do
        if MessageMetadata.IsOutgoingUser(message) and usableText(message.text, fits) then
          entries[#entries + 1] = { text = message.text, sentAt = tonumber(message.sentAt) or 0, key = key, index = index }
        end
      end
    end
  end
  return entries
end

-- Newest first; on a same-second tie the later line of a chat comes first.
local function newerFirst(left, right)
  if left.sentAt ~= right.sentAt then
    return left.sentAt > right.sentAt
  end
  if left.key ~= right.key then
    return tostring(left.key) < tostring(right.key)
  end
  return left.index > right.index
end

-- fits (optional) drops lines the open chat would refuse. It runs before
-- neighbouring duplicates collapse, so a dropped line never splits a run.
function SentHistory.Build(conversations, fits)
  if type(conversations) ~= "table" then
    return {}
  end
  local entries = collect(conversations, fits)
  table.sort(entries, newerFirst)
  local list = {}
  for _, entry in ipairs(entries) do
    if entry.text ~= list[#list] then
      list[#list + 1] = entry.text
      if #list >= SentHistory.MAX_ENTRIES then
        break
      end
    end
  end
  return list
end

ns.SentHistory = SentHistory
return SentHistory
