local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Gateway = {}

local function resolveCharacterWhisperSender(api)
  if type(api) == "table" and type(api.SendChatMessage) == "function" then
    return api.SendChatMessage
  end
  if type(_G.SendChatMessage) == "function" then
    return _G.SendChatMessage
  end
  return nil
end

local function resolveBattleNetWhisperSender(api)
  if type(api) == "table" and type(api.SendWhisper) == "function" then
    return api.SendWhisper
  end
  if type(_G.BNSendWhisper) == "function" then
    return _G.BNSendWhisper
  end
  return nil
end

function Gateway.CanSendCharacterWhisper(api)
  return resolveCharacterWhisperSender(api) ~= nil
end

function Gateway.SendCharacterWhisper(api, target, text)
  local sendWhisper = resolveCharacterWhisperSender(api)
  if sendWhisper == nil then
    error("No character whisper sender available")
  end
  return sendWhisper(text, "WHISPER", nil, target)
end

function Gateway.CanSendBattleNetWhisper(api)
  return resolveBattleNetWhisperSender(api) ~= nil
end

function Gateway.SendBattleNetWhisper(api, bnetAccountID, text)
  local sendWhisper = resolveBattleNetWhisperSender(api)
  if sendWhisper == nil then
    error("No Battle.net whisper sender available")
  end
  return sendWhisper(bnetAccountID, text)
end

function Gateway.RequestAvailability(api, guid)
  if type(api) ~= "table" or type(api.RequestCanLocalWhisperTarget) ~= "function" then
    return
  end
  pcall(api.RequestCanLocalWhisperTarget, guid)
end

ns.WhisperGateway = Gateway

return Gateway
