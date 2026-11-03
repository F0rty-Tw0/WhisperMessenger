local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")

-- Finds the stored message a reaction operation points at: newest first,
-- by wire id when the sender had one, else by source-text fingerprint;
-- group reactions must also match the target's GUID and name.
local Targeting = {}

local function textFingerprint(message, canonicalizeText)
  local text = type(message) == "table" and message.text or ""
  if type(canonicalizeText) == "function" then
    text = canonicalizeText(text)
  end
  return Protocol.Fingerprint(text)
end

local function normalizedName(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  local ok, normalized = pcall(string.lower, value)
  return ok and normalized or nil
end

local function groupTargetMatches(message, operation)
  local targetGuid = operation.targetGuid
  local targetName = normalizedName(operation.targetName)
  if (type(targetGuid) ~= "string" or targetGuid == "") and targetName == nil then
    return false
  end
  if type(targetGuid) == "string" and targetGuid ~= "" and message.guid ~= targetGuid then
    return false
  end
  return targetName == nil or normalizedName(message.playerName) == targetName
end

function Targeting.FindTarget(state, conversationKey, operation, targetDirection, canonicalizeText)
  local conversation = state.store and state.store.conversations and state.store.conversations[conversationKey]
  if type(conversation) ~= "table" then
    return nil
  end
  local isGroupReaction = operation.type == "groupReaction"
  local messages = conversation.messages or {}
  if operation.wireId ~= nil then
    for index = #messages, 1, -1 do
      local message = messages[index]
      if
        message.kind == "user"
        and (isGroupReaction or message.direction == targetDirection)
        and message.wireId == operation.wireId
        and textFingerprint(message, canonicalizeText) == operation.sourceFingerprint
        and (not isGroupReaction or groupTargetMatches(message, operation))
      then
        return message
      end
    end
    return nil
  end

  for index = #messages, 1, -1 do
    local message = messages[index]
    if
      message.kind == "user"
      and (isGroupReaction or message.direction == targetDirection)
      and textFingerprint(message, canonicalizeText) == operation.sourceFingerprint
      and (not isGroupReaction or groupTargetMatches(message, operation))
    then
      return message
    end
  end
  return nil
end

ns.MessageReactionsTargeting = Targeting
return Targeting
