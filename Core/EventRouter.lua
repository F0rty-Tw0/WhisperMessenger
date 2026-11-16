local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
local PendingOutgoing = ns.EventRouterPendingOutgoing or require("WhisperMessenger.Core.EventRouter.PendingOutgoing")
local QuestLinkText = ns.QuestLinkText or require("WhisperMessenger.Model.QuestLinkText")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local SecretString = ns.GroupChatIngestSecretString or require("WhisperMessenger.Core.Ingest.GroupChatIngest.SecretString")
local MessageRequests = ns.MessageRequests or require("WhisperMessenger.Model.MessageRequests")
local FailedWhisper = ns.EventRouterFailedWhisper or require("WhisperMessenger.Core.EventRouter.FailedWhisper")
local MessageReplies = ns.MessageReplies or require("WhisperMessenger.Model.MessageReplies")
local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")
local MessageParts = ns.MessageParts or require("WhisperMessenger.Model.MessageParts")
local PartMerge = ns.EventRouterPartMerge or require("WhisperMessenger.Core.EventRouter.PartMerge")
local IncomingFilter = ns.IncomingFilter or require("WhisperMessenger.Core.Ingest.IncomingFilter")
local WhisperMessage = ns.EventRouterWhisperMessage or require("WhisperMessenger.Core.EventRouter.WhisperMessage")
local AddonMessage = ns.EventRouterAddonMessage or require("WhisperMessenger.Core.EventRouter.AddonMessage")
local AddonGreetingIngest = ns.EventRouterAddonGreetingIngest or require("WhisperMessenger.Core.EventRouter.AddonGreetingIngest")

local buildConversationContact = WhisperMessage.BuildConversationContact
local buildMessage = WhisperMessage.BuildMessage
local confirmWhisperAvailability = WhisperMessage.ConfirmWhisperAvailability
local conversationWithKey = WhisperMessage.ConversationWithKey
local isOpen = WhisperMessage.IsOpen
local isWhisperProofFresh = WhisperMessage.IsWhisperProofFresh
local battleNetReactionSenderKey = AddonMessage.BattleNetReactionSenderKey
local resolveWhisperReactionConversation = AddonMessage.ResolveWhisperReactionConversation
local recordConvertedReactionFallbackActivity = AddonMessage.RecordConvertedReactionFallbackActivity

local Router = {}
Router._isSecretString = SecretString.IsSecretString

function Router.RecordPendingSend(state, target, text, metadata)
  return PendingOutgoing.Record(state, target, text, metadata)
end

local function handleUnlockedEvent(state, eventName, payload)
  if type(payload) ~= "table" or SecretString.PayloadHasSecretFields(payload, Router._isSecretString) then
    return nil
  end
  if eventName == "CHAT_MSG_ADDON" then
    return AddonMessage.HandleCharacter(state, payload)
  end

  if eventName == "BN_CHAT_MSG_ADDON" then
    return AddonMessage.HandleBattleNet(state, payload)
  end

  if eventName == "CHAT_MSG_SYSTEM" then
    return FailedWhisper.Handle(state, payload.text)
  end

  if eventName == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
    if payload.guid == nil then
      return nil
    end

    local avail = Availability.FromStatus(payload.status)
    avail.rawStatus = payload.rawStatus
    -- A whisper exchange proves reachability, so keep it over the ambiguous
    -- WrongFaction, and over Offline for WHISPER_PROOF_SECONDS after the
    -- whisper. A guild/community roster showing them offline always wins.
    local existing = state.availabilityByGUID[payload.guid]
    local now = state.now and state.now() or 0
    if
      existing
      and existing.canWhisper
      and existing.confirmedByWhisper
      and PresenceCache.GetPresence(payload.guid) ~= "offline"
      and (avail.status == "WrongFaction" or (avail.status == "Offline" and isWhisperProofFresh(existing, now)))
    then
      return existing
    end
    state.availabilityByGUID[payload.guid] = avail
    if (existing == nil or existing.status ~= avail.status) and type(state.onAvailabilityChanged) == "function" then
      state.onAvailabilityChanged(payload.guid)
    end
    return avail
  end

  if
    eventName == "CHAT_MSG_WHISPER"
    or eventName == "CHAT_MSG_WHISPER_INFORM"
    or eventName == "CHAT_MSG_AFK"
    or eventName == "CHAT_MSG_DND"
    or eventName == "CHAT_MSG_BN_WHISPER"
    or eventName == "CHAT_MSG_BN_WHISPER_INFORM"
    or eventName == "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE"
  then
    local contact, conversationKey = buildConversationContact(state, payload)
    if conversationKey == nil then
      return nil
    end

    local isActive = isOpen(state, conversationKey)
    local replayedAt = payload.replayedAt
    local sentAt = replayedAt or state.now()
    local outgoingFromPendingSend = false

    if eventName == "CHAT_MSG_WHISPER" or eventName == "CHAT_MSG_BN_WHISPER" then
      local addonGreeting, hideGreeting
      if eventName == "CHAT_MSG_WHISPER" then
        addonGreeting, hideGreeting = AddonGreetingIngest.ClaimForWhisper(state, contact, payload, sentAt)
        if hideGreeting then
          return nil
        end
      end
      local incomingMessage = buildMessage(state, payload, contact, "in", "user", sentAt)
      incomingMessage.addonGreeting = addonGreeting
      local correlationText = QuestLinkText.CanonicalizeForTransport(incomingMessage.text)
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
        reactionActorName = resolvedConversation and (resolvedConversation.displayName or resolvedConversation.contactDisplayName)
          or reactionActorName
      end
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
        if controlResult.staged then
          return nil, {
            reactionControl = true,
            reactionStaged = true,
          }
        end
        if controlResult.converted then
          recordConvertedReactionFallbackActivity(state, controlResult, reactionConversationKey)
          return conversationWithKey(state, reactionConversationKey),
            {
              reactionControl = true,
              reactionChanged = controlResult.changed == true,
              reactionOperation = controlResult.operation,
            }
        end
        if controlResult.degraded then
          return degradedConversation, {
            reactionDegraded = true,
          }
        end
      end

      local isNewConversation = state.store.conversations[conversationKey] == nil
      if replayedAt then
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
    elseif eventName == "CHAT_MSG_WHISPER_INFORM" or eventName == "CHAT_MSG_BN_WHISPER_INFORM" then
      confirmWhisperAvailability(state, payload, contact)
      local fromPending, pendingText, pendingEntry = PendingOutgoing.Resolve(state, conversationKey, payload, sentAt)
      outgoingFromPendingSend = fromPending
      local informPayload = payload
      if pendingText ~= nil and pendingText ~= payload.text then
        informPayload = {}
        for k, v in pairs(payload) do
          informPayload[k] = v
        end
        informPayload.text = pendingText
      end

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
          return conversationWithKey(state, conversationKey),
            {
              outgoingFromPendingSend = true,
              reactionControl = true,
              reactionChanged = changed == true,
            }
        end
      end

      local outgoingMessage = buildMessage(state, informPayload, contact, "out", "user", sentAt)
      outgoingMessage.wireId = pendingEntry and pendingEntry.wireId or nil
      outgoingMessage.replyTo = pendingEntry and pendingEntry.replyTo or nil
      MessageParts.ApplyMetadata(outgoingMessage, pendingEntry)
      -- A replayed reply older than the newest message leaves unread alone.
      local isNewest = true
      if replayedAt then
        local _, insertedNewest = Store.InsertOutgoingChronological(state.store, conversationKey, outgoingMessage)
        isNewest = insertedNewest
      else
        Store.AppendOutgoing(state.store, conversationKey, outgoingMessage)
      end
      PartMerge.AfterStore(state, conversationKey, outgoingMessage)
      if isNewest then
        Store.MarkRead(state.store, conversationKey)
      end
    elseif eventName == "CHAT_MSG_AFK" or eventName == "CHAT_MSG_DND" then
      Store.SetActiveStatus(state.store, conversationKey, {
        eventName = eventName,
        text = payload.text,
        sentAt = sentAt,
        lineID = payload.lineID,
      })
    else
      Store.AppendIncoming(state.store, conversationKey, buildMessage(state, payload, contact, "in", "system", sentAt), isActive)
    end

    return conversationWithKey(state, conversationKey), { outgoingFromPendingSend = outgoingFromPendingSend }
  end

  return nil
end

-- Only character whispers are filtered: the ignore key is a character name.
function Router.HandleEvent(state, eventName, payload)
  if eventName == "CHAT_MSG_WHISPER" and type(payload) == "table" then
    if IncomingFilter.Evaluate(state, "whisper", payload.playerName, payload.text, payload.lineID, eventName) ~= "pass" then
      return nil
    end
  end
  return handleUnlockedEvent(state, eventName, payload)
end

ns.EventRouter = Router

return Router
