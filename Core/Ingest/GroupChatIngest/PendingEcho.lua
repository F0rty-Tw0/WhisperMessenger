local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local GroupSendPending = ns.BootstrapWindowRuntimeGroupSendPending or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPending")

-- Group sends waiting for their own chat echo (state.pendingGroupOutgoing,
-- keyed by conversation). The echo claims its send so the stored message
-- keeps the send's wire id or reaction control.
local PendingEcho = {}

-- Drops sends whose echo never came in time; the send side owns the queue.
PendingEcho.PruneAll = GroupSendPending.PruneAll

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
