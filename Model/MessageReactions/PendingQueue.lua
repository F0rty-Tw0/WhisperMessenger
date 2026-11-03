local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")

-- Per-sender queues of reaction side messages waiting for their partner
-- (identity <-> whisper, operation <-> chat fallback): recording with a
-- per-sender cap, TTL expiry on a timer, and clearing.
local PendingQueue = {}
local TTL_SECONDS = Protocol.PAIRING_TTL_SECONDS
local MAX_PENDING_PER_SENDER = 32
local PENDING_QUEUE_FIELDS = {
  "identityMetadata",
  "identityMessages",
  "operations",
  "controls",
}

function PendingQueue.RuntimeState(state)
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

function PendingQueue.EnforceSenderCap(runtime, senderKey)
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

function PendingQueue.PurgeSender(runtime, senderKey, now)
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

function PendingQueue.Expire(state, now)
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
    PendingQueue.Expire(state, callbackNow)
    scheduleCleanup(state)
  end)
  scheduling = false
end

function PendingQueue.Record(state, runtime, queues, senderKey, entry)
  runtime.nextSequence = (runtime.nextSequence or 0) + 1
  entry.sequence = runtime.nextSequence
  table.insert(queueFor(queues, senderKey), entry)
  PendingQueue.EnforceSenderCap(runtime, senderKey)
  scheduleCleanup(state, entry.recordedAt + TTL_SECONDS)
end

function PendingQueue.ClearConversation(state, conversationKey)
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

function PendingQueue.FlushControls(state)
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

function PendingQueue.ClearAll(state)
  if type(state) == "table" then
    state.messageReactionRuntime = nil
    state.messageReactionCleanupDueAt = nil
  end
end

PendingQueue.InvokeDegrade = invokeDegrade
PendingQueue.FIELDS = PENDING_QUEUE_FIELDS

ns.MessageReactionsPendingQueue = PendingQueue
return PendingQueue
