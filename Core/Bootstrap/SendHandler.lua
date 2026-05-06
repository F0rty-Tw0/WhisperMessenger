local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
local Router = ns.EventRouter or require("WhisperMessenger.Core.EventRouter")
local Gateway = ns.WhisperGateway or require("WhisperMessenger.Transport.WhisperGateway")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local QuestLinkClassic = ns.UIHyperlinksQuestLinkClassic or require("WhisperMessenger.UI.Hyperlinks.QuestLinkClassic")

local SendHandler = {}

local function isCombatSendLocked(runtime)
  if runtime.isChatMessagingLocked and runtime.isChatMessagingLocked() then
    return true
  end

  -- Guard direct SendChatMessage usage during combat even when runtime-level
  -- lockdown queueing is disabled; insecure addon calls are blocked here.
  return type(_G.InCombatLockdown) == "function" and _G.InCombatLockdown() or false
end

local function appendBlockedOutgoing(runtime, payload, reason)
  if runtime == nil or runtime.store == nil or payload == nil or payload.conversationKey == nil then
    return
  end

  local now = runtime.now and runtime.now() or 0
  local blockedMessage = {
    id = tostring(now),
    eventName = "WHISPERMESSENGER_OUTGOING_BLOCKED",
    direction = "out",
    kind = "user",
    text = payload.text,
    sentAt = now,
    guid = payload.guid,
    playerName = payload.displayName or payload.target,
    channel = payload.channel or "WOW",
    bnetAccountID = payload.bnetAccountID,
    gameAccountName = payload.gameAccountName,
    delivery = "blocked",
    blockedReason = reason,
  }

  if type(runtime.store.config) == "table" then
    Store.AppendOutgoing(runtime.store, payload.conversationKey, blockedMessage)
    return
  end

  runtime.store.conversations = runtime.store.conversations or {}
  local conversation = runtime.store.conversations[payload.conversationKey]
  if conversation == nil then
    conversation = { messages = {}, unreadCount = 0, lastPreview = nil, lastActivityAt = 0 }
    runtime.store.conversations[payload.conversationKey] = conversation
  end

  conversation.messages = conversation.messages or {}
  table.insert(conversation.messages, blockedMessage)
  conversation.lastPreview = blockedMessage.text
  conversation.lastActivityAt = blockedMessage.sentAt
  conversation.displayName = blockedMessage.playerName or conversation.displayName
  conversation.channel = blockedMessage.channel or conversation.channel
end

function SendHandler.HandleSend(runtime, payload, refreshWindow)
  runtime.sendStatusByConversation[payload.conversationKey] = nil

  -- Convert Classic plain-text quest links (`[Name (id)]`) into real
  -- hyperlinks before send so the recipient gets a clickable link and the
  -- echoed CHAT_MSG_*_INFORM event matches what we recorded.
  if type(payload.text) == "string" then
    payload.text = QuestLinkClassic.Rewrite(payload.text)
  end

  if isCombatSendLocked(runtime) then
    appendBlockedOutgoing(runtime, payload, "Lockdown")
    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Lockdown")
    refreshWindow()
    return false
  end

  if runtime.isMythicLockdown and runtime.isMythicLockdown() then
    appendBlockedOutgoing(runtime, payload, "Mythic Lockdown")
    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Mythic Lockdown")
    refreshWindow()
    return false
  end

  if runtime.isCompetitiveContent and runtime.isCompetitiveContent() then
    appendBlockedOutgoing(runtime, payload, "Competitive Content")
    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Competitive Content")
    refreshWindow()
    return false
  end

  local sendAvailable
  if payload.channel == "BN" then
    sendAvailable = payload.bnetAccountID ~= nil and Gateway.CanSendBattleNetWhisper(runtime.bnetApi)
  else
    sendAvailable = Gateway.CanSendCharacterWhisper(runtime.chatApi)
  end

  if not sendAvailable then
    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Send unavailable")
    refreshWindow()
    return false
  end

  local pendingConversationKey = Router.RecordPendingSend(runtime, payload, payload.text)
  local callOk, sendOk
  if payload.channel == "BN" then
    callOk, sendOk = pcall(Gateway.SendBattleNetWhisper, runtime.bnetApi, payload.bnetAccountID, payload.text)
  else
    -- SendChatMessage is hardware-event-protected; pcall breaks the
    -- propagation chain causing ADDON_ACTION_FORBIDDEN.  Call directly
    -- and let WoW's error handler surface failures instead.
    Gateway.SendCharacterWhisper(runtime.chatApi, payload.target, payload.text)
    callOk = true
    sendOk = true
  end

  if not callOk or sendOk == false then
    local pending = runtime.pendingOutgoing[pendingConversationKey]
    if pending and #pending > 0 then
      table.remove(pending, #pending)
      if #pending == 0 then
        runtime.pendingOutgoing[pendingConversationKey] = nil
      end
    end

    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Send failed")
    refreshWindow()
    return false
  end

  refreshWindow()
  return true
end

ns.BootstrapSendHandler = SendHandler
return SendHandler
