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

local EventBridge = {}

local function buildLivePayload(runtime, eventName, ...)
  local BNetResolver = loadModule("WhisperMessenger.Transport.BNetResolver", "BNetResolver")

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
  local Constants = loadModule("WhisperMessenger.Core.Constants", "Constants")
  for _, eventName in ipairs(Constants.LIVE_EVENT_NAMES) do
    frame:RegisterEvent(eventName)
  end
end

function EventBridge.RouteLiveEvent(runtime, refreshWindow, eventName, ...)
  if runtime == nil then
    return nil
  end
  local Router = loadModule("WhisperMessenger.Core.EventRouter", "EventRouter")
  local result = Router.HandleEvent(runtime, eventName, buildLivePayload(runtime, eventName, ...))
  if refreshWindow then
    refreshWindow()
  end
  return result
end

ns.BootstrapEventBridge = EventBridge
return EventBridge
