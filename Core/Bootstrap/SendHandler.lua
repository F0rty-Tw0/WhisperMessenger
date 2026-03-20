local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Loader = ns.Loader
  or (
    type(require) == "function"
    and (function()
      local ok, L = pcall(require, "WhisperMessenger.Core.Loader")
      return ok and L or nil
    end)()
  )
local loadModule = Loader and Loader.LoadModule
  or function(name, key)
    if ns[key] then
      return ns[key]
    end
    if type(require) == "function" then
      local ok, loaded = pcall(require, name)
      if ok then
        return loaded
      end
    end
    error(key .. " module not available")
  end

local SendHandler = {}

function SendHandler.HandleSend(runtime, payload, refreshWindow)
  local Availability = loadModule("WhisperMessenger.Transport.Availability", "Availability")
  local Router = loadModule("WhisperMessenger.Core.EventRouter", "EventRouter")
  local Gateway = loadModule("WhisperMessenger.Transport.WhisperGateway", "WhisperGateway")

  runtime.sendStatusByConversation[payload.conversationKey] = nil

  if runtime.isChatMessagingLocked and runtime.isChatMessagingLocked() then
    runtime.sendStatusByConversation[payload.conversationKey] = Availability.FromStatus("Lockdown")
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
    callOk = pcall(Gateway.SendCharacterWhisper, runtime.chatApi, payload.target, payload.text)
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
