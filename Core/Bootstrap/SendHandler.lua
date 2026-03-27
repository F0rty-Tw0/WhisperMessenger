local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
local Router = ns.EventRouter or require("WhisperMessenger.Core.EventRouter")
local Gateway = ns.WhisperGateway or require("WhisperMessenger.Transport.WhisperGateway")

local SendHandler = {}

function SendHandler.HandleSend(runtime, payload, refreshWindow)
  runtime.sendStatusByConversation[payload.conversationKey] = nil

  if runtime.isChatMessagingLocked and runtime.isChatMessagingLocked() then
    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Lockdown")
    refreshWindow()
    return false
  end

  if runtime.isMythicLockdown and runtime.isMythicLockdown() then
    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Mythic Lockdown")
    refreshWindow()
    return false
  end

  local sendAvailable
  if payload.channel == "BN" then
    sendAvailable = payload.bnetAccountID ~= nil and type(runtime.bnetApi.SendWhisper) == "function"
  else
    sendAvailable = type(runtime.chatApi.SendChatMessage) == "function"
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
