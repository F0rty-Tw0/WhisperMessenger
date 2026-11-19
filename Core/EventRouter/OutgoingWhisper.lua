local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local PendingOutgoing = ns.EventRouterPendingOutgoing or require("WhisperMessenger.Core.EventRouter.PendingOutgoing")
local QuestLinkText = ns.QuestLinkText or require("WhisperMessenger.Model.QuestLinkText")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local MessageParts = ns.MessageParts or require("WhisperMessenger.Model.MessageParts")
local PartMerge = ns.EventRouterPartMerge or require("WhisperMessenger.Core.EventRouter.PartMerge")
local WhisperMessage = ns.EventRouterWhisperMessage or require("WhisperMessenger.Core.EventRouter.WhisperMessage")
local CharacterRedirect = ns.EventRouterCharacterRedirect or require("WhisperMessenger.Core.EventRouter.CharacterRedirect")

local buildMessage = WhisperMessage.BuildMessage
local confirmWhisperAvailability = WhisperMessage.ConfirmWhisperAvailability
local conversationWithKey = WhisperMessage.ConversationWithKey

-- CHAT_MSG_WHISPER_INFORM and CHAT_MSG_BN_WHISPER_INFORM: the echo of a
-- whisper we sent, matched against the pending send that caused it.
local OutgoingWhisper = {}

-- The echo of a reaction we sent: true plus the router's result once the
-- reaction is applied to its target.
local function pendingReactionOutcome(state, conversationKey, pendingEntry, sentAt)
  local reactionControl = pendingEntry and pendingEntry.reactionControl
  if reactionControl and reactionControl.operation then
    local changed, target = MessageReactions.ApplyOperation(
      state,
      conversationKey,
      reactionControl.operation,
      reactionControl.actorName,
      "in",
      sentAt,
      QuestLinkText.Serialize
    )
    if target then
      reactionControl.confirmed = true
      MessageReactions.ClearPending(target, reactionControl.pendingToken)
      return true,
        conversationWithKey(state, conversationKey),
        {
          outgoingFromPendingSend = true,
          reactionControl = true,
          reactionChanged = changed == true,
        }
    end
  end
  return false
end

function OutgoingWhisper.Handle(state, payload, contact, conversationKey, sentAt, mergeEntry)
  confirmWhisperAvailability(state, payload, contact)
  local fromPending, pendingText, pendingEntry = PendingOutgoing.Resolve(state, conversationKey, payload, sentAt)
  local informPayload = payload
  if pendingText ~= nil and pendingText ~= payload.text then
    informPayload = {}
    for k, v in pairs(payload) do
      informPayload[k] = v
    end
    informPayload.text = pendingText
  end

  local isReaction, conversation, meta = pendingReactionOutcome(state, conversationKey, pendingEntry, sentAt)
  if isReaction then
    return conversation, meta
  end

  local outgoingMessage = buildMessage(state, informPayload, contact, "out", "user", sentAt)
  CharacterRedirect.Stamp(outgoingMessage, mergeEntry)
  outgoingMessage.wireId = pendingEntry and pendingEntry.wireId or nil
  outgoingMessage.replyTo = pendingEntry and pendingEntry.replyTo or nil
  MessageParts.ApplyMetadata(outgoingMessage, pendingEntry)
  -- A replayed reply older than the newest message leaves unread alone.
  local isNewest = true
  if payload.replayedAt then
    local _, insertedNewest = Store.InsertOutgoingChronological(state.store, conversationKey, outgoingMessage)
    isNewest = insertedNewest
  else
    Store.AppendOutgoing(state.store, conversationKey, outgoingMessage)
  end
  PartMerge.AfterStore(state, conversationKey, outgoingMessage)
  if isNewest then
    Store.MarkRead(state.store, conversationKey)
  end
  return conversationWithKey(state, conversationKey), { outgoingFromPendingSend = fromPending }
end

ns.EventRouterOutgoingWhisper = OutgoingWhisper

return OutgoingWhisper
