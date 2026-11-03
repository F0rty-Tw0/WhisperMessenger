local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")
local MessageParts = ns.MessageParts or require("WhisperMessenger.Model.MessageParts")
local PendingQueue = ns.MessageReactionsPendingQueue or require("WhisperMessenger.Model.MessageReactions.PendingQueue")
local SenderAlias = ns.MessageReactionsSenderAlias or require("WhisperMessenger.Model.MessageReactions.SenderAlias")
local Targeting = ns.MessageReactionsTargeting or require("WhisperMessenger.Model.MessageReactions.Targeting")
local PendingReaction = ns.MessageReactionsPendingReaction or require("WhisperMessenger.Model.MessageReactions.PendingReaction")

local MessageReactions = {}
local runtimeState = PendingQueue.RuntimeState
local purgeSender = PendingQueue.PurgeSender
local recordPending = PendingQueue.Record
local invokeDegrade = PendingQueue.InvokeDegrade

MessageReactions.ResolveSenderAlias = SenderAlias.Resolve
MessageReactions.AssociateSenderAlias = SenderAlias.Associate
MessageReactions.Expire = PendingQueue.Expire

function MessageReactions.IsEligible(message, channelOverride)
  local messageChannel
  if type(message) == "table" then
    messageChannel = message.channel
  end
  local channel = messageChannel
  if channel == nil then
    channel = channelOverride
  end
  -- Whispers (legacy "WOW"/"BN" keys) plus the addon-message group channels.
  local eligibleChannel = channel == "WOW" or channel == "BN" or ChannelType.ADDON_GROUP_CHANNELS[channel] == true
  return type(message) == "table"
    and eligibleChannel
    and (channelOverride == nil or channelOverride == channel)
    and message.kind == "user"
    and message.direction == "in"
    and message.isCensored ~= true
    and message.delivery ~= "blocked"
end

function MessageReactions.AttachIncomingIdentity(state, senderKey, conversationKey, message, now, correlationText)
  if type(state) ~= "table" or type(senderKey) ~= "string" or type(message) ~= "table" then
    return false
  end
  local runtime = runtimeState(state)
  purgeSender(runtime, senderKey, now)
  local metadataQueue = runtime.identityMetadata[senderKey]
  local fingerprint = Protocol.Fingerprint(type(correlationText) == "string" and correlationText or message.text)
  if type(metadataQueue) == "table" then
    for index, entry in ipairs(metadataQueue) do
      if (entry.conversationKey == nil or entry.conversationKey == conversationKey) and entry.metadata.sourceFingerprint == fingerprint then
        message.wireId = entry.metadata.wireId
        MessageParts.ApplyMetadata(message, entry.metadata)
        table.remove(metadataQueue, index)
        if #metadataQueue == 0 then
          runtime.identityMetadata[senderKey] = nil
        end
        return true
      end
    end
  end

  recordPending(state, runtime, runtime.identityMessages, senderKey, {
    conversationKey = conversationKey,
    message = message,
    sourceFingerprint = fingerprint,
    recordedAt = now,
  })
  return false
end

function MessageReactions.RecordIdentity(state, senderKey, conversationKey, metadata, now)
  if type(state) ~= "table" or type(senderKey) ~= "string" or type(metadata) ~= "table" or metadata.type ~= "identity" then
    return nil
  end
  local runtime = runtimeState(state)
  purgeSender(runtime, senderKey, now)
  local messageQueue = runtime.identityMessages[senderKey]
  if type(messageQueue) == "table" then
    for index, entry in ipairs(messageQueue) do
      if (conversationKey == nil or entry.conversationKey == conversationKey) and entry.sourceFingerprint == metadata.sourceFingerprint then
        entry.message.wireId = metadata.wireId
        MessageParts.ApplyMetadata(entry.message, metadata)
        table.remove(messageQueue, index)
        if #messageQueue == 0 then
          runtime.identityMessages[senderKey] = nil
        end
        return entry.message
      end
    end
  end

  recordPending(state, runtime, runtime.identityMetadata, senderKey, {
    conversationKey = conversationKey,
    metadata = metadata,
    recordedAt = now,
  })
  return nil
end

function MessageReactions.ApplyOperation(state, conversationKey, operation, actorName, targetDirection, now, canonicalizeText)
  if
    type(state) ~= "table"
    or type(operation) ~= "table"
    or (operation.type ~= "reaction" and operation.type ~= "groupReaction")
    or (operation.type == "groupReaction" and (type(operation.sourceFingerprint) ~= "string" or type(operation.fallbackFingerprint) ~= "string" or operation.targetGuid == nil or operation.targetName == nil or (operation.targetGuid == "" and operation.targetName == "")))
    or not Protocol.IsReactionKey(operation.key)
    or (operation.operation ~= "set" and operation.operation ~= "remove")
  then
    return false, nil
  end

  local target = Targeting.FindTarget(state, conversationKey, operation, targetDirection, canonicalizeText)
  if target == nil then
    return false, nil
  end

  if operation.operation == "remove" then
    if type(target.reaction) ~= "table" or target.reaction.key ~= operation.key then
      return false, target
    end
    target.reaction = nil
    return true, target
  end

  if type(target.reaction) == "table" and target.reaction.key == operation.key then
    return false, target
  end
  target.reaction = {
    key = operation.key,
    actorName = actorName,
    updatedAt = now,
  }
  return true, target
end

function MessageReactions.DiscardIdentityCandidate(state, senderKey, message)
  local runtime = type(state) == "table" and state.messageReactionRuntime or nil
  local identityMessages = type(runtime) == "table" and runtime.identityMessages or nil
  if type(identityMessages) ~= "table" then
    return
  end
  local queue = identityMessages[senderKey]
  if type(queue) ~= "table" then
    return
  end
  for index = #queue, 1, -1 do
    if queue[index].message == message then
      table.remove(queue, index)
    end
  end
  if #queue == 0 then
    identityMessages[senderKey] = nil
  end
end

local function resolveMatchedControl(state, senderKey, entry, operation, actorName, targetDirection, now, canonicalizeText)
  MessageReactions.DiscardIdentityCandidate(state, senderKey, entry.message)
  local changed, target = MessageReactions.ApplyOperation(state, entry.conversationKey, operation, actorName, targetDirection, now, canonicalizeText)
  if target == nil then
    invokeDegrade(entry)
    return {
      degraded = true,
      converted = false,
      changed = false,
      conversationKey = entry.conversationKey,
    }
  end
  return {
    converted = true,
    changed = changed,
    operation = operation.operation,
    message = target,
    incomingFallbackMessage = entry.message,
    incomingFallbackIsActive = entry.incomingFallbackIsActive,
    conversationKey = entry.conversationKey,
  }
end

function MessageReactions.RecordOperation(state, senderKey, conversationKey, actorName, operation, targetDirection, now, canonicalizeText)
  if
    type(state) ~= "table"
    or type(senderKey) ~= "string"
    or type(operation) ~= "table"
    or (operation.type ~= "reaction" and operation.type ~= "groupReaction")
  then
    return nil
  end
  local runtime = runtimeState(state)
  purgeSender(runtime, senderKey, now)
  local controlQueue = runtime.controls[senderKey]
  if type(controlQueue) == "table" then
    for index, entry in ipairs(controlQueue) do
      if (conversationKey == nil or entry.conversationKey == conversationKey) and entry.fallbackFingerprint == operation.fallbackFingerprint then
        table.remove(controlQueue, index)
        if #controlQueue == 0 then
          runtime.controls[senderKey] = nil
        end
        return resolveMatchedControl(state, senderKey, entry, operation, entry.actorName, targetDirection, now, canonicalizeText)
      end
    end
  end

  recordPending(state, runtime, runtime.operations, senderKey, {
    conversationKey = conversationKey,
    actorName = actorName,
    operation = operation,
    targetDirection = targetDirection,
    canonicalizeText = canonicalizeText,
    recordedAt = now,
  })
  return nil
end

function MessageReactions.ConsumeIncomingControl(
  state,
  senderKey,
  conversationKey,
  actorName,
  message,
  targetDirection,
  now,
  onDegrade,
  correlationText,
  parseFallback,
  incomingFallbackIsActive
)
  if type(state) ~= "table" or type(senderKey) ~= "string" or type(message) ~= "table" or type(message.text) ~= "string" then
    return nil
  end
  local runtime = runtimeState(state)
  purgeSender(runtime, senderKey, now)
  local parser = type(parseFallback) == "function" and parseFallback or Protocol.ParseFallback
  local parsedFallback = parser(message.text)
  local correlation = type(correlationText) == "string" and correlationText or message.text
  if parsedFallback ~= nil then
    correlation = string.gsub(correlation, " +$", "")
  end
  local fallbackFingerprint = Protocol.Fingerprint(correlation)
  local operationQueue = runtime.operations[senderKey]
  if type(operationQueue) == "table" then
    for index, entry in ipairs(operationQueue) do
      if
        (entry.conversationKey == nil or entry.conversationKey == conversationKey) and entry.operation.fallbackFingerprint == fallbackFingerprint
      then
        table.remove(operationQueue, index)
        if #operationQueue == 0 then
          runtime.operations[senderKey] = nil
        end
        return resolveMatchedControl(state, senderKey, {
          conversationKey = conversationKey,
          message = message,
          onDegrade = onDegrade,
          incomingFallbackIsActive = incomingFallbackIsActive,
        }, entry.operation, actorName, targetDirection, now, entry.canonicalizeText)
      end
    end
  end

  if parsedFallback == nil then
    return nil
  end
  recordPending(state, runtime, runtime.controls, senderKey, {
    conversationKey = conversationKey,
    actorName = actorName,
    message = message,
    fallbackFingerprint = fallbackFingerprint,
    targetDirection = targetDirection,
    recordedAt = now,
    onDegrade = onDegrade,
    incomingFallbackIsActive = incomingFallbackIsActive,
  })
  return {
    staged = true,
    conversationKey = conversationKey,
  }
end

MessageReactions.VisibleReaction = PendingReaction.VisibleReaction
MessageReactions.NewPendingToken = PendingReaction.NewPendingToken
MessageReactions.ClearPending = PendingReaction.ClearPending
MessageReactions.BeginPending = PendingReaction.BeginPending
MessageReactions.ClearTransient = PendingReaction.ClearTransient
MessageReactions.ClearConversation = PendingQueue.ClearConversation
MessageReactions.FlushControls = PendingQueue.FlushControls
MessageReactions.ClearAll = PendingQueue.ClearAll

ns.MessageReactions = MessageReactions
return MessageReactions
