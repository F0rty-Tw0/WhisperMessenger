local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
local PendingOutgoing = ns.EventRouterPendingOutgoing or require("WhisperMessenger.Core.EventRouter.PendingOutgoing")
local QuestLinkExchange = ns.QuestLinkExchange or require("WhisperMessenger.Model.QuestLinkExchange")
local MessageReactionProtocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local SecretString = ns.GroupChatIngestSecretString or require("WhisperMessenger.Core.Ingest.GroupChatIngest.SecretString")
local GroupChatIngest = ns.GroupChatIngest or require("WhisperMessenger.Core.Ingest.GroupChatIngest")

local QUEST_LINK_ADDON_PREFIX = "WMQL"
local REACTION_ADDON_PREFIX = "WMRX"

local GROUP_REACTION_CHANNELS = {
  PARTY = true,
  RAID = true,
  INSTANCE_CHAT = true,
  GUILD = true,
  OFFICER = true,
}

-- QuestLinkClassic loads after this module in the TOC, so resolve it lazily.
local function getQuestLinkClassic()
  return ns.UIHyperlinksQuestLinkClassic or (rawget(_G, "require") and require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic"))
end
local function canonicalReactionText(text)
  local questLinks = getQuestLinkClassic()
  if questLinks and type(questLinks.CanonicalizeForTransport) == "function" then
    return questLinks.CanonicalizeForTransport(text)
  end
  return text
end
local function canonicalTargetText(text)
  local questLinks = getQuestLinkClassic()
  if questLinks and type(questLinks.Serialize) == "function" then
    return questLinks.Serialize(text)
  end
  return text
end

local function battleNetReactionSenderKey(state, payload)
  if payload.bnetAccountID ~= nil then
    local canonicalKey = "bn:" .. tostring(payload.bnetAccountID)
    if payload.gameAccountID ~= nil then
      MessageReactions.AssociateSenderAlias(state, "bngame:" .. tostring(payload.gameAccountID), canonicalKey)
    end
    return canonicalKey
  end
  if payload.gameAccountID ~= nil then
    return MessageReactions.ResolveSenderAlias(state, "bngame:" .. tostring(payload.gameAccountID))
  end
  return nil
end

local Router = {}
Router._isSecretString = SecretString.IsSecretString

local function checkCensored(lineID)
  local chatApi = _G.C_ChatInfo
  if chatApi == nil or type(chatApi.IsChatLineCensored) ~= "function" then
    return nil
  end
  if lineID == nil then
    return nil
  end
  local ok, censored = pcall(chatApi.IsChatLineCensored, lineID)
  if ok and censored == true then
    return true
  end
  return nil
end

local function buildConversationContact(state, payload)
  if payload.channel == "BN" then
    if payload.bnetAccountID == nil then
      return nil, nil
    end

    local contact = Identity.FromBattleNet(payload.bnetAccountID, payload.accountInfo, payload.playerInfo)
    if contact.canonicalName == "" then
      return nil, nil
    end
    local conversationKey = Identity.BuildConversationKey(state.localProfileId, contact.contactKey)
    return contact, conversationKey
  end

  -- Only a nil-check here: comparing a tainted chat payload against a literal
  -- string trips Blizzard's secret-string protection. We defer the "empty
  -- name" rejection to the canonicalName check below — normalizeName pcalls
  -- Ambiguate/string.lower, so tainted names degrade to "" safely.
  if payload.playerName == nil then
    return nil, nil
  end

  local contact = Identity.FromWhisper(payload.playerName, payload.guid, payload.playerInfo)
  if contact.canonicalName == "" then
    return nil, nil
  end
  local conversationKey = Identity.BuildConversationKey(state.localProfileId, contact.contactKey)
  return contact, conversationKey
end
local function confirmWhisperAvailability(state, payload, contact)
  local guid = payload.guid or (contact and contact.guid or nil)
  if guid == nil then
    return
  end
  local availability = Availability.FromStatus("CanWhisper")
  availability.confirmedByWhisper = true
  state.availabilityByGUID = state.availabilityByGUID or {}
  state.availabilityByGUID[guid] = availability
end

local function localSenderClassTag()
  if type(_G.UnitClass) ~= "function" then
    return nil
  end
  local ok, _, classTag = pcall(_G.UnitClass, "player")
  if ok and type(classTag) == "string" and classTag ~= "" then
    return classTag
  end
  return nil
end

local function localSenderName()
  if type(_G.UnitName) ~= "function" then
    return nil
  end
  local ok, name = pcall(_G.UnitName, "player")
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

local function buildMessage(state, eventName, payload, contact, direction, kind, sentAt)
  local senderClassTag
  local senderName
  if direction == "out" then
    -- Stamp the sending character's class and name so the bubble icon and
    -- "You — <char>" label survive relogging to another character.
    senderClassTag = localSenderClassTag()
    senderName = localSenderName()
  end
  -- WoW Classic's character-whisper protocol strips real quest hyperlinks
  -- on the wire, so CHAT_MSG_WHISPER and CHAT_MSG_WHISPER_INFORM can arrive
  -- carrying plain `[Name (id)]` text even when the original outgoing
  -- message was a hyperlink. Rewrite here so bubbles always render a
  -- clickable link. Idempotent on already-hyperlinked text.
  local messageText = payload.text
  if type(messageText) == "string" then
    local questLinks = getQuestLinkClassic()
    if questLinks and type(questLinks.Rewrite) == "function" then
      messageText = questLinks.Rewrite(messageText)
    end
    -- Classic strips the `(id)` too, leaving just `[Name]`. The paired
    -- addon-message side channel carries the id back; splice it in here.
    -- Character whispers key the inbox by player name; BNet whispers key by
    -- bnetAccountID so the link survives even if the friend hops characters.
    if direction == "in" then
      local senderKey
      if payload.channel == "BN" and payload.bnetAccountID ~= nil then
        senderKey = "bn:" .. tostring(payload.bnetAccountID)
      elseif payload.playerName then
        senderKey = payload.playerName
      end
      if senderKey then
        local now = state.now and state.now() or 0
        messageText = QuestLinkExchange.Splice(state, senderKey, messageText, now)
      end
    end
  end
  return {
    id = tostring(payload.lineID or sentAt),
    eventName = eventName,
    direction = direction,
    kind = kind,
    text = messageText,
    sentAt = sentAt,
    lineID = payload.lineID,
    guid = payload.guid or (contact and contact.guid or nil),
    playerName = (contact and contact.displayName) or payload.playerName,
    channel = (contact and contact.channel) or payload.channel or "WOW",
    bnetAccountID = (contact and contact.bnetAccountID) or payload.bnetAccountID,
    battleTag = (contact and contact.battleTag) or payload.battleTag,
    gameAccountName = (contact and contact.gameAccountName) or payload.gameAccountName,
    className = (contact and contact.className) or payload.className,
    classTag = (contact and contact.classTag) or payload.classTag,
    senderClassTag = senderClassTag,
    senderName = senderName,
    raceName = (contact and contact.raceName) or payload.raceName,
    raceTag = (contact and contact.raceTag) or payload.raceTag,
    factionName = (contact and contact.factionName) or payload.factionName,
    isCensored = payload.isCensored or checkCensored(payload.lineID),
  }
end

function Router.RecordPendingSend(state, target, text, metadata)
  return PendingOutgoing.Record(state, target, text, metadata)
end

local function resolveWhisperReactionConversation(state, playerName, computedConversationKey)
  return Identity.ResolveWhisperConversation(state, playerName, "WOW") or computedConversationKey
end

local function recordConvertedReactionFallbackActivity(state, result, fallbackConversationKey)
  if result.changed ~= true or result.operation ~= "set" then
    return
  end
  local conversationKey = result.conversationKey or fallbackConversationKey
  if conversationKey == nil then
    return
  end
  Store.RecordIncomingActivity(state.store, conversationKey, result.incomingFallbackMessage, result.incomingFallbackIsActive)
end

local function reactionSenderContext(state, payload, isBattleNet)
  if isBattleNet then
    local senderKey = battleNetReactionSenderKey(state, payload)
    if senderKey == nil then
      return nil, nil, nil, nil, nil
    end
    local conversationKey = payload.bnetAccountID ~= nil and Identity.ResolveWhisperConversation(state, payload.bnetAccountID, "BN") or nil
    local conversation = conversationKey and state.store.conversations[conversationKey] or nil
    local actorName = conversation
        and (conversation.displayName or conversation.contactDisplayName or conversation.battleTag or conversation.gameAccountName)
      or tostring(payload.bnetAccountID or senderKey)
    return senderKey, conversationKey, actorName, conversationKey, senderKey
  end

  if type(payload.playerName) ~= "string" then
    return nil, nil, nil, nil, nil
  end
  local contact, computedConversationKey = buildConversationContact(state, payload)
  if contact == nil then
    return nil, nil, nil, nil, nil
  end
  local conversationKey = resolveWhisperReactionConversation(state, payload.playerName, computedConversationKey)
  local conversation = state.store.conversations[conversationKey]
  local actorName = conversation and (conversation.displayName or conversation.contactDisplayName) or contact.displayName or payload.playerName
  return conversationKey, conversationKey, actorName, conversationKey, conversationKey
end

local function handleReactionMetadata(state, payload, isBattleNet)
  local metadata = MessageReactionProtocol.Decode(payload.text)
  if metadata == nil then
    return nil
  end
  local senderKey, conversationKey, actorName, identityConversationKey, reactionSenderKey = reactionSenderContext(state, payload, isBattleNet)
  if senderKey == nil then
    return nil
  end
  local now = state.now and state.now() or 0
  if metadata.type == "identity" then
    MessageReactions.RecordIdentity(state, senderKey, identityConversationKey, metadata, now)
    return nil
  end
  if metadata.type ~= "reaction" then
    return nil
  end
  local result = MessageReactions.RecordOperation(state, reactionSenderKey, conversationKey, actorName, metadata, "out", now, canonicalTargetText)

  if result and result.converted then
    local resolvedConversationKey = result.conversationKey or conversationKey
    recordConvertedReactionFallbackActivity(state, result, resolvedConversationKey)

    local conversation = resolvedConversationKey and state.store.conversations[resolvedConversationKey] or nil
    if conversation then
      conversation.conversationKey = resolvedConversationKey
    end
    return conversation,
      {
        reactionControl = true,
        reactionChanged = result.changed == true,
        reactionOperation = result.operation,
      }
  end
  return nil
end

local function handleUnlockedEvent(state, eventName, payload)
  if type(payload) ~= "table" or SecretString.PayloadHasSecretFields(payload, Router._isSecretString) then
    return nil
  end
  if eventName == "CHAT_MSG_ADDON" then
    if payload.prefix == REACTION_ADDON_PREFIX and payload.channel == "WHISPER" then
      return handleReactionMetadata(state, payload, false)
    end
    if payload.prefix == REACTION_ADDON_PREFIX and GROUP_REACTION_CHANNELS[payload.channel] then
      return GroupChatIngest.HandleAddonEvent(state, payload)
    end
    if payload.prefix == QUEST_LINK_ADDON_PREFIX and payload.channel == "WHISPER" and type(payload.playerName) == "string" then
      local now = state.now and state.now() or 0
      QuestLinkExchange.RecordIncoming(state, payload.playerName, payload.text, now)
    end
    return nil
  end

  if eventName == "BN_CHAT_MSG_ADDON" then
    if payload.prefix == REACTION_ADDON_PREFIX then
      return handleReactionMetadata(state, payload, true)
    end
    if payload.prefix == QUEST_LINK_ADDON_PREFIX and payload.bnetAccountID ~= nil then
      local now = state.now and state.now() or 0
      QuestLinkExchange.RecordIncoming(state, "bn:" .. tostring(payload.bnetAccountID), payload.text, now)
    end
    return nil
  end

  if eventName == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
    if payload.guid == nil then
      return nil
    end

    local avail = Availability.FromStatus(payload.status)
    avail.rawStatus = payload.rawStatus
    -- Don't downgrade CanWhisper set by a recent successful whisper.
    -- A whisper exchange proves reachability; the async availability API
    -- may return WrongFaction for cross-realm same-faction players.
    local existing = state.availabilityByGUID[payload.guid]
    if existing and existing.canWhisper and existing.confirmedByWhisper and not avail.canWhisper then
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

    local isActive = state.activeConversationKey == conversationKey
    if state.isConversationOpen then
      isActive = state.isConversationOpen(conversationKey) == true
    end
    local sentAt = state.now()
    local outgoingFromPendingSend = false

    if eventName == "CHAT_MSG_WHISPER" or eventName == "CHAT_MSG_BN_WHISPER" then
      local incomingMessage = buildMessage(state, eventName, payload, contact, "in", "user", sentAt)
      local correlationText = canonicalReactionText(incomingMessage.text)
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
      local reactionIsActive = state.activeConversationKey == reactionConversationKey
      if state.isConversationOpen then
        reactionIsActive = state.isConversationOpen(reactionConversationKey) == true
      end
      confirmWhisperAvailability(state, payload, contact)
      local routeComplete = false
      local degradedConversation
      local function appendDegraded(message)
        local active = state.activeConversationKey == conversationKey
        if state.isConversationOpen then
          active = state.isConversationOpen(conversationKey) == true
        end
        degradedConversation = Store.InsertIncomingChronological(state.store, conversationKey, message, active)
        if degradedConversation then
          degradedConversation.conversationKey = conversationKey
        end
        if routeComplete and type(state.onReactionFallbackDegraded) == "function" then
          state.onReactionFallbackDegraded(degradedConversation)
        end
      end

      local identitySenderKey = senderKey
      local identityConversationKey = conversationKey
      if eventName == "CHAT_MSG_WHISPER" then
        identitySenderKey = reactionSenderKey
        identityConversationKey = reactionConversationKey
      end

      MessageReactions.AttachIncomingIdentity(state, identitySenderKey, identityConversationKey, incomingMessage, sentAt, correlationText)
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
          local conversation = state.store.conversations[reactionConversationKey]
          if conversation then
            conversation.conversationKey = reactionConversationKey
          end
          return conversation,
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

      Store.AppendIncoming(state.store, conversationKey, incomingMessage, isActive)
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
          canonicalTargetText
        )
        if target then
          reactionControl.confirmed = true
          MessageReactions.ClearPending(target, reactionControl.pendingToken)
          local conversation = state.store.conversations[conversationKey]
          if conversation then
            conversation.conversationKey = conversationKey
          end
          return conversation,
            {
              outgoingFromPendingSend = true,
              reactionControl = true,
              reactionChanged = changed == true,
            }
        end
      end

      local outgoingMessage = buildMessage(state, eventName, informPayload, contact, "out", "user", sentAt)
      outgoingMessage.wireId = pendingEntry and pendingEntry.wireId or nil
      Store.AppendOutgoing(state.store, conversationKey, outgoingMessage)
      Store.MarkRead(state.store, conversationKey)
    elseif eventName == "CHAT_MSG_AFK" or eventName == "CHAT_MSG_DND" then
      Store.SetActiveStatus(state.store, conversationKey, {
        eventName = eventName,
        text = payload.text,
        sentAt = sentAt,
        lineID = payload.lineID,
      })
    else
      Store.AppendIncoming(state.store, conversationKey, buildMessage(state, eventName, payload, contact, "in", "system", sentAt), isActive)
    end

    local conversation = state.store.conversations[conversationKey]
    if conversation then
      conversation.conversationKey = conversationKey
    end
    return conversation, { outgoingFromPendingSend = outgoingFromPendingSend }
  end

  return nil
end

function Router.HandleEvent(state, eventName, payload)
  return handleUnlockedEvent(state, eventName, payload)
end

ns.EventRouter = Router

return Router
