local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")

local MessageReactions = {}
local TTL_SECONDS = 15
local MAX_PENDING_PER_SENDER = 32
local PENDING_QUEUE_FIELDS = {
  "identityMetadata",
  "identityMessages",
  "operations",
  "controls",
}

local function runtimeState(state)
  state.messageReactionRuntime = state.messageReactionRuntime
    or {
      identityMetadata = {},
      identityMessages = {},
      operations = {},
      controls = {},
      senderAliases = {},
    }
  return state.messageReactionRuntime
end

local function queueFor(queues, senderKey)
  queues[senderKey] = queues[senderKey] or {}
  return queues[senderKey]
end

local function invokeDegrade(entry)
  if type(entry.onDegrade) == "function" then
    entry.onDegrade(entry.message)
  end
end

local function enforceSenderCap(runtime, senderKey)
  while true do
    local count = 0
    local oldestEntry
    local oldestField
    local oldestQueue
    local oldestIndex
    for _, field in ipairs(PENDING_QUEUE_FIELDS) do
      local queue = runtime[field][senderKey]
      for index, entry in ipairs(queue or {}) do
        count = count + 1
        if
          oldestEntry == nil
          or entry.recordedAt < oldestEntry.recordedAt
          or (entry.recordedAt == oldestEntry.recordedAt and (entry.sequence or 0) < (oldestEntry.sequence or 0))
        then
          oldestEntry = entry
          oldestField = field
          oldestQueue = queue
          oldestIndex = index
        end
      end
    end
    if count <= MAX_PENDING_PER_SENDER then
      return
    end
    local evicted = table.remove(oldestQueue, oldestIndex)
    if #oldestQueue == 0 then
      runtime[oldestField][senderKey] = nil
    end
    if oldestField == "controls" then
      invokeDegrade(evicted)
    end
  end
end

local function mergeSenderQueue(queues, aliasKey, canonicalKey)
  local aliasQueue = queues[aliasKey]
  if aliasQueue == nil then
    return
  end
  local canonicalQueue = queues[canonicalKey]
  if canonicalQueue == nil then
    canonicalQueue = aliasQueue
    queues[canonicalKey] = canonicalQueue
  else
    for _, entry in ipairs(aliasQueue) do
      table.insert(canonicalQueue, entry)
    end
  end
  queues[aliasKey] = nil
  table.sort(canonicalQueue, function(left, right)
    if left.recordedAt ~= right.recordedAt then
      return left.recordedAt < right.recordedAt
    end
    return (left.sequence or 0) < (right.sequence or 0)
  end)
end

function MessageReactions.ResolveSenderAlias(state, senderKey)
  local runtime = type(state) == "table" and state.messageReactionRuntime or nil
  local aliases = type(runtime) == "table" and runtime.senderAliases or nil
  return type(aliases) == "table" and aliases[senderKey] or senderKey
end

function MessageReactions.AssociateSenderAlias(state, aliasKey, canonicalKey)
  if type(state) ~= "table" or type(aliasKey) ~= "string" or type(canonicalKey) ~= "string" or aliasKey == canonicalKey then
    return false
  end
  local runtime = runtimeState(state)
  runtime.senderAliases = runtime.senderAliases or {}
  local aliases = runtime.senderAliases
  if aliases[aliasKey] ~= nil and aliases[aliasKey] ~= canonicalKey then
    return false
  end
  aliases[aliasKey] = canonicalKey
  for _, field in ipairs(PENDING_QUEUE_FIELDS) do
    mergeSenderQueue(runtime[field], aliasKey, canonicalKey)
  end
  enforceSenderCap(runtime, canonicalKey)
  return true
end

local function purgeQueue(queue, now, degradeExpired)
  local index = 1
  while index <= #queue do
    local entry = queue[index]
    if now - entry.recordedAt >= TTL_SECONDS then
      table.remove(queue, index)
      if degradeExpired then
        invokeDegrade(entry)
      end
    else
      index = index + 1
    end
  end
end

local function purgeQueues(queues, now, degradeExpired)
  for senderKey, queue in pairs(queues) do
    purgeQueue(queue, now, degradeExpired)
    if #queue == 0 then
      queues[senderKey] = nil
    end
  end
end

local function hasPendingForSender(runtime, senderKey)
  for _, field in ipairs(PENDING_QUEUE_FIELDS) do
    local queue = runtime[field][senderKey]
    if type(queue) == "table" and #queue > 0 then
      return true
    end
  end
  return false
end

local function pruneSenderAliases(runtime)
  local aliases = runtime.senderAliases
  if type(aliases) ~= "table" then
    return
  end
  for aliasKey, canonicalKey in pairs(aliases) do
    if not hasPendingForSender(runtime, aliasKey) and not hasPendingForSender(runtime, canonicalKey) then
      aliases[aliasKey] = nil
    end
  end
end

local function currentTime(state, fallback)
  if type(state.now) == "function" then
    local ok, now = pcall(state.now)
    if ok and type(now) == "number" then
      return now
    end
  end
  return fallback
end
local function purgeSender(runtime, senderKey, now)
  for _, field in ipairs(PENDING_QUEUE_FIELDS) do
    local queue = runtime[field][senderKey]
    if queue then
      purgeQueue(queue, now, field == "controls")
      if #queue == 0 then
        runtime[field][senderKey] = nil
      end
    end
  end
end

function MessageReactions.Expire(state, now)
  if type(state) ~= "table" or type(state.messageReactionRuntime) ~= "table" then
    return
  end
  local runtime = state.messageReactionRuntime
  local at = type(now) == "number" and now or currentTime(state, 0)
  purgeQueues(runtime.identityMetadata, at, false)
  purgeQueues(runtime.identityMessages, at, false)
  purgeQueues(runtime.operations, at, false)
  purgeQueues(runtime.controls, at, true)
  pruneSenderAliases(runtime)
end

local function earliestDeadline(runtime)
  local earliest
  for _, field in ipairs(PENDING_QUEUE_FIELDS) do
    for _, queue in pairs(runtime[field]) do
      for _, entry in ipairs(queue) do
        local deadline = entry.recordedAt + TTL_SECONDS
        if earliest == nil or deadline < earliest then
          earliest = deadline
        end
      end
    end
  end
  return earliest
end

local function scheduleCleanup(state, deadline)
  local runtime = state.messageReactionRuntime
  local timer = _G.C_Timer
  if type(runtime) ~= "table" or type(timer) ~= "table" or type(timer.After) ~= "function" then
    return
  end
  deadline = deadline or earliestDeadline(runtime)
  if deadline == nil then
    return
  end
  local scheduledDeadline = state.messageReactionCleanupDueAt
  if type(scheduledDeadline) == "number" and scheduledDeadline <= deadline then
    return
  end

  state.messageReactionCleanupDueAt = deadline
  local now = currentTime(state, deadline - TTL_SECONDS)
  local scheduling = true
  timer.After(math.max(0, deadline - now), function()
    if state.messageReactionCleanupDueAt ~= deadline then
      return
    end
    local callbackNow = currentTime(state, deadline)
    if callbackNow < deadline then
      if not scheduling then
        state.messageReactionCleanupDueAt = nil
        scheduleCleanup(state)
      end
      return
    end
    state.messageReactionCleanupDueAt = nil
    MessageReactions.Expire(state, callbackNow)
    scheduleCleanup(state)
  end)
  scheduling = false
end

local function recordPending(state, runtime, queues, senderKey, entry)
  runtime.nextSequence = (runtime.nextSequence or 0) + 1
  entry.sequence = runtime.nextSequence
  table.insert(queueFor(queues, senderKey), entry)
  enforceSenderCap(runtime, senderKey)
  scheduleCleanup(state, entry.recordedAt + TTL_SECONDS)
end

local function textFingerprint(message, canonicalizeText)
  local text = type(message) == "table" and message.text or ""
  if type(canonicalizeText) == "function" then
    text = canonicalizeText(text)
  end
  return Protocol.Fingerprint(text)
end

function MessageReactions.IsEligible(message, channelOverride)
  local messageChannel
  if type(message) == "table" then
    messageChannel = message.channel
  end
  local channel = messageChannel
  if channel == nil then
    channel = channelOverride
  end
  local eligibleChannel = channel == "WOW"
    or channel == "BN"
    or channel == "PARTY"
    or channel == "RAID"
    or channel == "INSTANCE_CHAT"
    or channel == "GUILD"
    or channel == "OFFICER"
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

local function findTarget(state, conversationKey, operation, targetDirection, canonicalizeText)
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

  local target = findTarget(state, conversationKey, operation, targetDirection, canonicalizeText)
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

function MessageReactions.VisibleReaction(message)
  if type(message) ~= "table" then
    return nil
  end
  local pending = message._pendingReaction
  if type(pending) == "table" then
    if pending.operation == "remove" then
      return nil
    end
    if pending.operation == "set" and Protocol.IsReactionKey(pending.key) then
      return pending
    end
  end
  return message.reaction
end

function MessageReactions.NewPendingToken(state)
  state.messageReactionPendingSequence = (state.messageReactionPendingSequence or 0) + 1
  return state.messageReactionPendingSequence
end

function MessageReactions.ClearPending(message, token)
  local pending = type(message) == "table" and message._pendingReaction or nil
  if type(pending) ~= "table" or pending.token ~= token then
    return false
  end
  message._pendingReaction = nil
  return true
end

function MessageReactions.BeginPending(message, token, operation, key, actorName, onTimeout)
  message._pendingReaction = {
    token = token,
    operation = operation,
    key = key,
    actorName = actorName,
  }
  local timer = _G.C_Timer
  if type(timer) ~= "table" or type(timer.After) ~= "function" then
    return
  end
  local scheduling = true
  timer.After(TTL_SECONDS, function()
    if not scheduling and MessageReactions.ClearPending(message, token) and type(onTimeout) == "function" then
      onTimeout()
    end
  end)
  scheduling = false
end

function MessageReactions.ClearTransient(state)
  if type(state) ~= "table" then
    return
  end
  local conversations = state.store and state.store.conversations or {}
  for _, conversation in pairs(conversations) do
    for _, message in ipairs(conversation.messages or {}) do
      message._pendingReaction = nil
    end
  end
  state.messageReactionPendingSequence = nil
end

function MessageReactions.ClearConversation(state, conversationKey)
  local runtime = type(state) == "table" and state.messageReactionRuntime or nil
  if type(runtime) ~= "table" then
    return
  end
  for _, queues in ipairs({
    runtime.identityMetadata,
    runtime.identityMessages,
    runtime.operations,
    runtime.controls,
  }) do
    for senderKey, queue in pairs(queues) do
      local index = 1
      while index <= #queue do
        if queue[index].conversationKey == conversationKey then
          table.remove(queue, index)
        else
          index = index + 1
        end
      end
      if #queue == 0 then
        queues[senderKey] = nil
      end
    end
  end
  pruneSenderAliases(runtime)
end

function MessageReactions.FlushControls(state)
  local runtime = type(state) == "table" and state.messageReactionRuntime or nil
  if type(runtime) ~= "table" then
    return
  end
  local controls = runtime.controls
  state.messageReactionRuntime = nil
  state.messageReactionCleanupDueAt = nil
  for _, queue in pairs(controls) do
    for _, entry in ipairs(queue) do
      invokeDegrade(entry)
    end
  end
end

function MessageReactions.ClearAll(state)
  if type(state) == "table" then
    state.messageReactionRuntime = nil
    state.messageReactionCleanupDueAt = nil
  end
end

MessageReactions.TTL_SECONDS = TTL_SECONDS

ns.MessageReactions = MessageReactions
return MessageReactions
