local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Gateway = {}

function Gateway.SendCharacterWhisper(api, target, text)
  api.SendChatMessage(text, "WHISPER", nil, target)
end

function Gateway.SendBattleNetWhisper(api, bnetAccountID, text)
  return api.SendWhisper(bnetAccountID, text)
end

function Gateway.RequestAvailability(api, guid)
  if api.RequestCanLocalWhisperTarget then
    api.RequestCanLocalWhisperTarget(guid)
  end
end

ns.WhisperGateway = Gateway

return Gateway
