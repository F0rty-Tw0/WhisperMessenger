local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")

-- The local player's own reaction while its send is in flight: shown in
-- place of the stored reaction until confirmed, cleared, or timed out.
local PendingReaction = {}
local TTL_SECONDS = Protocol.PAIRING_TTL_SECONDS

function PendingReaction.VisibleReaction(message)
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

function PendingReaction.NewPendingToken(state)
  state.messageReactionPendingSequence = (state.messageReactionPendingSequence or 0) + 1
  return state.messageReactionPendingSequence
end

function PendingReaction.ClearPending(message, token)
  local pending = type(message) == "table" and message._pendingReaction or nil
  if type(pending) ~= "table" or pending.token ~= token then
    return false
  end
  message._pendingReaction = nil
  return true
end

function PendingReaction.BeginPending(message, token, operation, key, actorName, onTimeout)
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
    if not scheduling and PendingReaction.ClearPending(message, token) and type(onTimeout) == "function" then
      onTimeout()
    end
  end)
  scheduling = false
end

function PendingReaction.ClearTransient(state)
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

ns.MessageReactionsPendingReaction = PendingReaction
return PendingReaction
