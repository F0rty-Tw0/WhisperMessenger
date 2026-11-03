local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PendingQueue = ns.MessageReactionsPendingQueue or require("WhisperMessenger.Model.MessageReactions.PendingQueue")

-- Maps a second sender key for the same player onto the canonical one and
-- folds the alias's pending queues into the canonical sender's queues.
local SenderAlias = {}

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

function SenderAlias.Resolve(state, senderKey)
  local runtime = type(state) == "table" and state.messageReactionRuntime or nil
  local aliases = type(runtime) == "table" and runtime.senderAliases or nil
  return type(aliases) == "table" and aliases[senderKey] or senderKey
end

function SenderAlias.Associate(state, aliasKey, canonicalKey)
  if type(state) ~= "table" or type(aliasKey) ~= "string" or type(canonicalKey) ~= "string" or aliasKey == canonicalKey then
    return false
  end
  local runtime = PendingQueue.RuntimeState(state)
  runtime.senderAliases = runtime.senderAliases or {}
  local aliases = runtime.senderAliases
  if aliases[aliasKey] ~= nil and aliases[aliasKey] ~= canonicalKey then
    return false
  end
  aliases[aliasKey] = canonicalKey
  for _, field in ipairs(PendingQueue.FIELDS) do
    mergeSenderQueue(runtime[field], aliasKey, canonicalKey)
  end
  PendingQueue.EnforceSenderCap(runtime, canonicalKey)
  return true
end

ns.MessageReactionsSenderAlias = SenderAlias
return SenderAlias
