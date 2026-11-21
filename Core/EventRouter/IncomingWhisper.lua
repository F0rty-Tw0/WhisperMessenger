local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local QuestLinkText = ns.QuestLinkText or require("WhisperMessenger.Model.QuestLinkText")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local MessageRequests = ns.MessageRequests or require("WhisperMessenger.Model.MessageRequests")
local MessageReplies = ns.MessageReplies or require("WhisperMessenger.Model.MessageReplies")
local PartMerge = ns.EventRouterPartMerge or require("WhisperMessenger.Core.EventRouter.PartMerge")
local AddonGreetingIngest = ns.EventRouterAddonGreetingIngest or require("WhisperMessenger.Core.EventRouter.AddonGreetingIngest")
local WhisperMessage = ns.EventRouterWhisperMessage or require("WhisperMessenger.Core.EventRouter.WhisperMessage")
local AddonMessage = ns.EventRouterAddonMessage or require("WhisperMessenger.Core.EventRouter.AddonMessage")
local CharacterRedirect = ns.EventRouterCharacterRedirect or require("WhisperMessenger.Core.EventRouter.CharacterRedirect")

local buildMessage = WhisperMessage.BuildMessage
local confirmWhisperAvailability = WhisperMessage.ConfirmWhisperAvailability
local conversationWithKey = WhisperMessage.ConversationWithKey
local isOpen = WhisperMessage.IsOpen
local battleNetReactionSenderKey = AddonMessage.BattleNetReactionSenderKey
local resolveWhisperReactionConversation = AddonMessage.ResolveWhisperReactionConversation
local recordConvertedReactionFallbackActivity = AddonMessage.RecordConvertedReactionFallbackActivity

-- CHAT_MSG_WHISPER and CHAT_MSG_BN_WHISPER: a reaction fallback is consumed
-- as a control, anything else is stored as a message.
local IncomingWhisper = {}

-- Who a reaction from this whisper belongs to. A character whisper resolves
-- to the stored conversation, so a base name finds its full-name thread.
local function reactionRoute(state, eventName, payload, contact, conversationKey)
  local senderKey
  if eventName == "CHAT_MSG_BN_WHISPER" then
    senderKey = battleNetReactionSenderKey(state, payload)
  else
    senderKey = payload.playerName
  end
  local reactionConversationKey = conversationKey
  local reactionSenderKey = senderKey
  local reactionActorName = (contact and contact.displayName) or payload.playerName
  if eventName == "CHAT_MSG_WHISPER" then
    reactionConversationKey = resolveWhisperReactionConversation(state, payload.playerName, conversationKey)
    reactionSenderKey = reactionConversationKey
    local resolvedConversation = state.store.conversations[reactionConversationKey]
    reactionActorName = resolvedConversation and (resolvedConversation.displayName or resolvedConversation.contactDisplayName) or reactionActorName
  end
  return senderKey, reactionSenderKey, reactionConversationKey, reactionActorName
end

-- The whisper was a reaction control: true plus the router's result.
local function controlOutcome(state, controlResult, reactionConversationKey, degradedConversation)
  if controlResult.staged then
    return true, nil, {
      reactionControl = true,
      reactionStaged = true,
    }
  end
  if controlResult.converted then
    recordConvertedReactionFallbackActivity(state, controlResult, reactionConversationKey)
    return true,
      conversationWithKey(state, reactionConversationKey),
      {
        reactionControl = true,
        reactionChanged = controlResult.changed == true,
        reactionOperation = controlResult.operation,
      }
  end
  if controlResult.degraded then
    return true, degradedConversation, {
      reactionDegraded = true,
    }
  end
  return false
end

-- opensNewChat: a fold just opened this friend's chat empty for the line.
local function storeIncoming(state, eventName, payload, contact, conversationKey, incomingMessage, isActive, opensNewChat)
  local isNewConversation = opensNewChat == true or state.store.conversations[conversationKey] == nil
  if payload.replayedAt then
    Store.InsertIncomingChronological(state.store, conversationKey, incomingMessage, isActive)
  else
    Store.AppendIncoming(state.store, conversationKey, incomingMessage, isActive)
  end
  PartMerge.AfterStore(state, conversationKey, incomingMessage)
  if isNewConversation and eventName == "CHAT_MSG_WHISPER" then
    MessageRequests.ClassifyNew(state, state.store.conversations[conversationKey], payload.guid, payload.playerName)
  end
  if eventName == "CHAT_MSG_WHISPER" then
    AddonGreetingIngest.AfterStore(state, contact, payload, conversationKey, incomingMessage, isNewConversation, isActive)
  end
end

function IncomingWhisper.Handle(state, eventName, payload, contact, conversationKey, isActive, sentAt, mergeEntry, opensNewChat)
  local addonGreeting, hideGreeting
  if eventName == "CHAT_MSG_WHISPER" then
    addonGreeting, hideGreeting = AddonGreetingIngest.ClaimForWhisper(state, contact, payload, sentAt)
    if hideGreeting then
      -- A fold opened this friend's chat for the hidden greeting alone.
      if opensNewChat == true then
        Store.Remove(state.store, conversationKey)
        -- Nothing is returned, so the router won't redraw: drop the empty row now.
        if type(state.refreshWindow) == "function" then
          state.refreshWindow()
        end
      end
      return nil
    end
  end
  local incomingMessage = buildMessage(state, payload, contact, "in", "user", sentAt)
  CharacterRedirect.Stamp(incomingMessage, mergeEntry)
  incomingMessage.addonGreeting = addonGreeting
  local correlationText = QuestLinkText.CanonicalizeForTransport(incomingMessage.text)
  local senderKey, reactionSenderKey, reactionConversationKey, reactionActorName = reactionRoute(state, eventName, payload, contact, conversationKey)
  local reactionIsActive = isOpen(state, reactionConversationKey)
  confirmWhisperAvailability(state, payload, contact)
  local routeComplete = false
  local degradedConversation
  local onDegraded = state.onReactionFallbackDegraded
  local function appendDegraded(message)
    local active = isOpen(state, conversationKey)
    degradedConversation = Store.InsertIncomingChronological(state.store, conversationKey, message, active)
    if degradedConversation then
      degradedConversation.conversationKey = conversationKey
    end
    if routeComplete and type(onDegraded) == "function" then
      onDegraded(degradedConversation)
    end
  end

  local identitySenderKey = senderKey
  local identityConversationKey = conversationKey
  if eventName == "CHAT_MSG_WHISPER" then
    identitySenderKey = reactionSenderKey
    identityConversationKey = reactionConversationKey
  end

  MessageReactions.AttachIncomingIdentity(state, identitySenderKey, identityConversationKey, incomingMessage, sentAt, correlationText)
  MessageReplies.ClaimStaged(state, identityConversationKey, incomingMessage, sentAt)
  local controlResult = MessageReactions.ConsumeIncomingControl(
    state,
    reactionSenderKey,
    reactionConversationKey,
    reactionActorName,
    incomingMessage,
    "out",
    sentAt,
    appendDegraded,
    correlationText,
    nil,
    reactionIsActive
  )
  routeComplete = true
  if controlResult then
    local isControl, conversation, meta = controlOutcome(state, controlResult, reactionConversationKey, degradedConversation)
    if isControl then
      return conversation, meta
    end
  end

  storeIncoming(state, eventName, payload, contact, conversationKey, incomingMessage, isActive, opensNewChat)
  return conversationWithKey(state, conversationKey), { outgoingFromPendingSend = false }
end

ns.EventRouterIncomingWhisper = IncomingWhisper

return IncomingWhisper
