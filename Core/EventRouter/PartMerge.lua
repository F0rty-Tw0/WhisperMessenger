local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local MessageParts = ns.MessageParts or require("WhisperMessenger.Model.MessageParts")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local MessageReplies = ns.MessageReplies or require("WhisperMessenger.Model.MessageReplies")

-- Where the router folds the parts of a long whisper into one bubble. Only
-- stored messages merge: a whisper paired at arrival is not stored yet, so
-- it merges once AfterStore runs.
local PartMerge = {}

-- After a part is stored: an incoming whisper, or the sender's echo.
function PartMerge.AfterStore(state, conversationKey, message)
  if type(message) ~= "table" or message.wireId == nil then
    return false
  end
  return MessageParts.Merge(Store.Find(state.store, conversationKey), message.wireId, message.direction)
end

-- Pairs an identity or manifest side message with stored whispers, then
-- merges each paired part. Returns the last paired message, or nil.
function PartMerge.RecordIdentity(state, senderKey, conversationKey, metadata, now)
  local records = metadata.type == "manifest" and metadata.records or { metadata }
  local lastPaired
  for _, record in ipairs(records) do
    local paired = MessageReactions.RecordIdentity(state, senderKey, conversationKey, record, now)
    if paired ~= nil then
      MessageReplies.ClaimStaged(state, conversationKey, paired, now)
      PartMerge.AfterStore(state, conversationKey, paired)
      lastPaired = paired
    end
  end
  return lastPaired
end

ns.EventRouterPartMerge = PartMerge
return PartMerge
