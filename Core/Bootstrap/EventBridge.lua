local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
local Constants = ns.Constants or require("WhisperMessenger.Core.Constants")
local EventRouter = ns.EventRouter or require("WhisperMessenger.Core.EventRouter")
local SoundPlayer = ns.SoundPlayer or require("WhisperMessenger.Core.SoundPlayer")

local Trace = ns.Trace

local EventBridge = {}

local function buildLivePayload(runtime, eventName, ...)
  if eventName == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
    local guid, status = ...
    return {
      guid = guid,
      status = BNetResolver.NormalizeAvailabilityStatus(status),
      rawStatus = status,
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

local function isUnknownEventError(err)
  local message = string.lower(tostring(err or ""))
  return string.find(message, "unknown event", 1, true) ~= nil
end

local function registerEventIfSupported(frame, eventName)
  local ok, err = pcall(frame.RegisterEvent, frame, eventName)
  if ok then
    return true
  end

  if isUnknownEventError(err) then
    if Trace then
      Trace("EventBridge: skipping unsupported event " .. tostring(eventName))
    end
    return false
  end

  error(err)
end

local function unregisterEventIfSupported(frame, eventName)
  local ok, err = pcall(frame.UnregisterEvent, frame, eventName)
  if ok then
    return true
  end

  if isUnknownEventError(err) then
    if Trace then
      Trace("EventBridge: skipping unsupported event " .. tostring(eventName))
    end
    return false
  end

  error(err)
end

function EventBridge.RegisterLiveEvents(frame)
  for _, eventName in ipairs(Constants.LIVE_EVENT_NAMES) do
    registerEventIfSupported(frame, eventName)
  end
end

function EventBridge.UnregisterLiveEvents(frame)
  for _, eventName in ipairs(Constants.LIVE_EVENT_NAMES) do
    if frame.UnregisterEvent then
      unregisterEventIfSupported(frame, eventName)
    end
  end
end

function EventBridge.UnregisterSuspendableLifecycleEvents(frame)
  local essential = Constants.MYTHIC_ESSENTIAL_EVENTS or {}
  for _, eventName in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
    if not essential[eventName] and frame.UnregisterEvent then
      unregisterEventIfSupported(frame, eventName)
    end
  end
end

function EventBridge.RegisterSuspendableLifecycleEvents(frame)
  local essential = Constants.MYTHIC_ESSENTIAL_EVENTS or {}
  for _, eventName in ipairs(Constants.LIFECYCLE_EVENT_NAMES) do
    if not essential[eventName] then
      registerEventIfSupported(frame, eventName)
    end
  end
end

local INCOMING_WHISPER_EVENTS = {
  CHAT_MSG_WHISPER = true,
  CHAT_MSG_BN_WHISPER = true,
}

local OUTGOING_WHISPER_EVENTS = {
  CHAT_MSG_WHISPER_INFORM = true,
  CHAT_MSG_BN_WHISPER_INFORM = true,
}

local TRACE_EVENTS = {
  CHAT_MSG_WHISPER = true,
  CHAT_MSG_WHISPER_INFORM = true,
  CHAT_MSG_BN_WHISPER = true,
  CHAT_MSG_BN_WHISPER_INFORM = true,
  CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE = true,
  CHAT_MSG_AFK = true,
  CHAT_MSG_DND = true,
}

function EventBridge.RouteLiveEvent(runtime, refreshWindow, eventName, ...)
  if runtime == nil then
    return nil
  end
  local payload = buildLivePayload(runtime, eventName, ...)
  if Trace and TRACE_EVENTS[eventName] then
    Trace(
      "EventBridge: "
        .. eventName
        .. " from="
        .. tostring(payload.playerName)
        .. " guid="
        .. tostring(payload.guid)
        .. " lineID="
        .. tostring(payload.lineID)
    )
  end
  local result = EventRouter.HandleEvent(runtime, eventName, payload)
  if Trace and TRACE_EVENTS[eventName] then
    if result and result.queued then
      Trace("EventBridge: queued (chat locked)")
    elseif result then
      Trace("EventBridge: routed OK, unread=" .. tostring(result.unreadCount))
    else
      Trace("EventBridge: result=nil (not processed)")
    end
  end
  if
    INCOMING_WHISPER_EVENTS[eventName]
    and runtime.accountState
    and runtime.accountState.settings
    and runtime.accountState.settings.playSoundOnWhisper == true
  then
    SoundPlayer.Play(runtime.accountState.settings)
  end
  if INCOMING_WHISPER_EVENTS[eventName] and result and result.conversationKey then
    -- Always track the last incoming whisper for reply (R key), even in combat
    runtime.lastIncomingWhisperKey = result.conversationKey
    if
      runtime.accountState
      and runtime.accountState.settings
      and runtime.accountState.settings.autoOpenWindow == true
      and runtime.onAutoOpen
      and type(_G.InCombatLockdown) == "function"
      and not _G.InCombatLockdown()
    then
      runtime.onAutoOpen(result.conversationKey)
    end
  end
  if OUTGOING_WHISPER_EVENTS[eventName] and result and result.conversationKey then
    if
      runtime.accountState
      and runtime.accountState.settings
      and runtime.accountState.settings.autoOpenWindow == true
      and runtime.onAutoOpenOutgoing
      and type(_G.InCombatLockdown) == "function"
      and not _G.InCombatLockdown()
    then
      runtime.onAutoOpenOutgoing(result.conversationKey)
    end
  end
  if refreshWindow then
    refreshWindow()
  end
  return result
end

ns.BootstrapEventBridge = EventBridge
return EventBridge
