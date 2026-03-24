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
    local accountInfo =
      BNetResolver.ResolveAccountInfo(runtime and runtime.bnetApi or _G.C_BattleNet or {}, bnetAccountID, guid)
    -- Resolve classTag/raceTag via GetPlayerInfoByGUID (BNet API only provides localized className)
    local playerGuid = accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.playerGuid or guid
    local playerInfo = BNetResolver.ResolvePlayerInfo(runtime and runtime.playerInfoByGUID or nil, playerGuid)
    return {
      text = text,
      playerName = playerName,
      lineID = lineID,
      -- Prefer the resolved playerGuid from the BNet API over the raw event
      -- guid, which may belong to a different player's character.
      guid = playerGuid,
      channel = "BN",
      bnetAccountID = bnetAccountID,
      accountInfo = accountInfo,
      playerInfo = playerInfo,
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

local WHISPER_SOUND_ID = 7355

local INCOMING_WHISPER_EVENTS = {
  CHAT_MSG_WHISPER = true,
  CHAT_MSG_BN_WHISPER = true,
}

function EventBridge.RouteLiveEvent(runtime, refreshWindow, eventName, ...)
  if runtime == nil then
    return nil
  end
  local result = EventRouter.HandleEvent(runtime, eventName, buildLivePayload(runtime, eventName, ...))
  if
    INCOMING_WHISPER_EVENTS[eventName]
    and runtime.accountState
    and runtime.accountState.settings
    and runtime.accountState.settings.playSoundOnWhisper == true
    and type(_G.PlaySound) == "function"
  then
    _G.PlaySound(WHISPER_SOUND_ID)
  end
  if refreshWindow then
    refreshWindow()
  end
  return result
end

ns.BootstrapEventBridge = EventBridge
return EventBridge
