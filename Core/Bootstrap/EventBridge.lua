local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
local Constants = ns.Constants or require("WhisperMessenger.Core.Constants")
local EventRouter = ns.EventRouter or require("WhisperMessenger.Core.EventRouter")

local EventBridge = {}

local function buildLivePayload(runtime, eventName, ...)
  if eventName == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
    local guid, status = ...
    return {
      guid = guid,
      status = BNetResolver.NormalizeAvailabilityStatus(status),
    }
  end

  if
    eventName == "CHAT_MSG_BN_WHISPER"
    or eventName == "CHAT_MSG_BN_WHISPER_INFORM"
    or eventName == "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE"
  then
    local text, playerName, _, _, _, _, _, _, _, _, lineID, guid, bnetAccountID = ...
    return {
      text = text,
      playerName = playerName,
      lineID = lineID,
      guid = guid,
      channel = "BN",
      bnetAccountID = bnetAccountID,
      accountInfo = BNetResolver.ResolveAccountInfo(
        runtime and runtime.bnetApi or _G.C_BattleNet or {},
        bnetAccountID,
        guid
      ),
    }
  end

  local text, playerName, _, _, _, _, _, _, _, _, lineID, guid = ...
  return {
    text = text,
    playerName = playerName,
    lineID = lineID,
    guid = guid,
    playerInfo = BNetResolver.ResolvePlayerInfo(runtime and runtime.playerInfoByGUID or nil, guid),
  }
end

function EventBridge.RegisterLiveEvents(frame)
  for _, eventName in ipairs(Constants.LIVE_EVENT_NAMES) do
    frame:RegisterEvent(eventName)
  end
end

function EventBridge.RouteLiveEvent(runtime, refreshWindow, eventName, ...)
  if runtime == nil then
    return nil
  end
  local result = EventRouter.HandleEvent(runtime, eventName, buildLivePayload(runtime, eventName, ...))
  if refreshWindow then
    refreshWindow()
  end
  return result
end

ns.BootstrapEventBridge = EventBridge
return EventBridge
