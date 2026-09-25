local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Group sends waiting for their own chat echo (state.pendingGroupOutgoing,
-- keyed by conversation). The echo claims its send so the stored message
-- keeps the send's wire id or reaction control.
local PendingEcho = {}

local ECHO_WINDOW = 15

local function prunePending(state, conversationKey, now)
  local queues = state.pendingGroupOutgoing
  local queue = type(queues) == "table" and queues[conversationKey] or nil
  if type(queue) ~= "table" then
    return nil
  end
  for index = #queue, 1, -1 do
    local entry = queue[index]
    if type(entry) ~= "table" or (type(entry.createdAt) == "number" and now - entry.createdAt > ECHO_WINDOW) then
      table.remove(queue, index)
    end
  end
  if #queue == 0 then
    queues[conversationKey] = nil
    return nil
  end
  return queue
end

-- Drops sends whose echo never came within ECHO_WINDOW seconds.
function PendingEcho.PruneAll(state, now)
  local queues = state.pendingGroupOutgoing
  if type(queues) ~= "table" then
    return
  end
  for conversationKey in pairs(queues) do
    prunePending(state, conversationKey, now)
  end
end

-- Removes and returns the pending send this echo belongs to, if any.
function PendingEcho.Consume(state, conversationKey, channel, text)
  local queues = state.pendingGroupOutgoing
  local queue = type(queues) == "table" and queues[conversationKey] or nil
  if type(queue) ~= "table" then
    return nil
  end
  for index, entry in ipairs(queue) do
    if entry.channel == channel and entry.text == text then
      table.remove(queue, index)
      if #queue == 0 then
        queues[conversationKey] = nil
      end
      return entry
    end
  end
  return nil
end

ns.GroupChatIngestPendingEcho = PendingEcho
return PendingEcho
