local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Group sends waiting for their own chat echo, kept per conversation in
-- runtime.pendingGroupOutgoing (shared with the group chat ingest).
local GroupSendPending = {}

local PENDING_MATCH_WINDOW_SECONDS = 15

-- A non-table entry is garbage and goes too.
local function isPendingDropped(entry, now)
  if type(entry) ~= "table" then
    return true
  end
  return type(now) == "number" and type(entry.createdAt) == "number" and now - entry.createdAt > PENDING_MATCH_WINDOW_SECONDS
end

-- Drops sends whose echo never came within PENDING_MATCH_WINDOW_SECONDS.
function GroupSendPending.Prune(runtime, conversationKey, now)
  local queues = runtime.pendingGroupOutgoing
  local queue = type(queues) == "table" and queues[conversationKey] or nil
  if type(queue) ~= "table" then
    return
  end
  for index = #queue, 1, -1 do
    if isPendingDropped(queue[index], now) then
      table.remove(queue, index)
    end
  end
  if #queue == 0 then
    queues[conversationKey] = nil
  end
end

function GroupSendPending.PruneAll(runtime, now)
  local queues = runtime.pendingGroupOutgoing
  if type(queues) ~= "table" then
    return
  end
  for conversationKey in pairs(queues) do
    GroupSendPending.Prune(runtime, conversationKey, now)
  end
end

-- The runtime clock, or 0 when it is missing or fails.
function GroupSendPending.Now(runtime)
  if type(runtime.now) == "function" then
    local ok, now = pcall(runtime.now)
    if ok and type(now) == "number" then
      return now
    end
  end
  return 0
end

function GroupSendPending.Record(runtime, conversationKey, entry, now)
  if type(conversationKey) ~= "string" or conversationKey == "" then
    return nil
  end
  GroupSendPending.PruneAll(runtime, now)
  runtime.pendingGroupOutgoing = runtime.pendingGroupOutgoing or {}
  local queue = runtime.pendingGroupOutgoing[conversationKey]
  if queue == nil then
    queue = {}
    runtime.pendingGroupOutgoing[conversationKey] = queue
  end
  table.insert(queue, entry)
  return entry
end

function GroupSendPending.Discard(runtime, conversationKey, entry)
  local queues = runtime.pendingGroupOutgoing
  local queue = type(queues) == "table" and queues[conversationKey] or nil
  if type(queue) ~= "table" then
    return
  end
  for index, candidate in ipairs(queue) do
    if candidate == entry then
      table.remove(queue, index)
      break
    end
  end
  if #queue == 0 then
    queues[conversationKey] = nil
  end
end

ns.BootstrapWindowRuntimeGroupSendPending = GroupSendPending

return GroupSendPending
