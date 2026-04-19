local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
local Constants = ns.Constants or require("WhisperMessenger.Core.Constants")
local EventRouter = ns.EventRouter or require("WhisperMessenger.Core.EventRouter")
local SoundPlayer = ns.SoundPlayer or require("WhisperMessenger.Core.SoundPlayer")
local ChannelMessageStore = ns.ChannelMessageStore or require("WhisperMessenger.Model.ChannelMessageStore")
local GroupChatIngest = ns.GroupChatIngest or require("WhisperMessenger.Core.Ingest.GroupChatIngest")

local Trace = ns.trace or require("WhisperMessenger.Core.Trace")
local EventUtils = ns.EventUtils or require("WhisperMessenger.Core.EventUtils")

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

local function traceSkippedEvent(eventName)
  if Trace then
    Trace("EventBridge: skipping unsupported event " .. tostring(eventName))
  end
end

local function registerEventIfSupported(frame, eventName)
  return EventUtils.RegisterEventIfSupported(frame, eventName, traceSkippedEvent)
end

local function unregisterEventIfSupported(frame, eventName)
  local ok, err = pcall(frame.UnregisterEvent, frame, eventName)
  if ok then
    return true
  end
  if EventUtils.IsUnknownEventError(err) then
    traceSkippedEvent(eventName)
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

function EventBridge.RegisterChannelEvents(frame)
  for _, eventName in ipairs(Constants.CHANNEL_EVENT_NAMES) do
    registerEventIfSupported(frame, eventName)
  end
end

function EventBridge.UnregisterChannelEvents(frame)
  for _, eventName in ipairs(Constants.CHANNEL_EVENT_NAMES) do
    if frame.UnregisterEvent then
      unregisterEventIfSupported(frame, eventName)
    end
  end
end

local CHANNEL_EVENTS = {
  CHAT_MSG_CHANNEL = true,
}

function EventBridge.RouteChannelEvent(runtime, eventName, ...)
  if runtime == nil or not CHANNEL_EVENTS[eventName] then
    return nil
  end
  local store = runtime.channelMessageStore
  if store == nil then
    return nil
  end
  local text, senderName, _, channelString = ...
  -- Extract base channel name (e.g. "2. Trade - City" → "Trade")
  local channelLabel = string.match(channelString or "", "^%d+%.%s*(.-)%s*%-") or channelString or ""
  if channelLabel == "" then
    channelLabel = channelString or ""
  end
  local sentAt = runtime.now and runtime.now() or 0
  ChannelMessageStore.Record(store, senderName, text, channelLabel, sentAt)
  return store
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
  -- Group chat events
  CHAT_MSG_PARTY = true,
  CHAT_MSG_PARTY_LEADER = true,
  CHAT_MSG_INSTANCE_CHAT = true,
  CHAT_MSG_INSTANCE_CHAT_LEADER = true,
  CHAT_MSG_BN_CONVERSATION = true,
}

local GROUP_EVENTS = {}
for _, name in ipairs(Constants.GROUP_EVENT_NAMES) do
  GROUP_EVENTS[name] = true
end

-- Attempt to resolve a BN conversation ID by iterating known conversations
-- and matching on bnSenderID. Returns nil when not resolvable.
-- pcall-guarded: BNGetNumConversations may be absent on Classic flavors.
local function resolveBNConversationID(bnSenderID)
  if bnSenderID == nil then
    return nil
  end
  local ok, numConversations = pcall(function()
    return _G.BNGetNumConversations and _G.BNGetNumConversations() or 0
  end)
  if not ok or type(numConversations) ~= "number" or numConversations < 1 then
    return nil
  end
  for i = 1, numConversations do
    local convOk, conversationID = pcall(function()
      local id = _G.BNGetConversationInfo and _G.BNGetConversationInfo(i)
      return id
    end)
    if convOk and conversationID ~= nil then
      return conversationID
    end
  end
  return nil
end

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
  local result, resultMeta = EventRouter.HandleEvent(runtime, eventName, payload)
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
    -- Do not touch Blizzard's reply-target helpers here. Under the secret-value
    -- system, mutating default chat reply state from addon code can taint the
    -- edit box and later break Blizzard reply UI in combat/instance contexts.
    -- We only need to track `lastIncomingWhisperKey`; the messenger reply hooks
    -- consume that key directly.
    local inGroupsTab = runtime.window
      and type(runtime.window.getTabMode) == "function"
      and runtime.window.getTabMode() == "groups"
    if
      runtime.accountState
      and runtime.accountState.settings
      and runtime.accountState.settings.autoOpenIncoming == true
      and runtime.onAutoOpen
      and type(_G.InCombatLockdown) == "function"
      and not _G.InCombatLockdown()
      and not inGroupsTab
    then
      runtime.onAutoOpen(result.conversationKey)
    end
  end
  if OUTGOING_WHISPER_EVENTS[eventName] and result and result.conversationKey then
    local inGroupsTabOut = runtime.window
      and type(runtime.window.getTabMode) == "function"
      and runtime.window.getTabMode() == "groups"
    if
      runtime.accountState
      and runtime.accountState.settings
      and runtime.accountState.settings.autoOpenOutgoing == true
      and runtime.onAutoOpenOutgoing
      and type(_G.InCombatLockdown) == "function"
      and not _G.InCombatLockdown()
      and not (resultMeta and resultMeta.outgoingFromPendingSend == true)
      and not inGroupsTabOut
    then
      runtime.onAutoOpenOutgoing(result.conversationKey)
    end
  end
  if refreshWindow then
    refreshWindow()
  end
  return result
end

function EventBridge.RegisterGroupEvents(frame)
  for _, eventName in ipairs(Constants.GROUP_EVENT_NAMES) do
    registerEventIfSupported(frame, eventName)
  end
end

function EventBridge.UnregisterGroupEvents(frame)
  for _, eventName in ipairs(Constants.GROUP_EVENT_NAMES) do
    if frame.UnregisterEvent then
      unregisterEventIfSupported(frame, eventName)
    end
  end
end

-- Resolve (clubId, streamId, clubType) for the most recent community chat
-- line. Blizzard's API takes no args and returns info about the last message —
-- reliable inside a CHAT_MSG_COMMUNITIES_CHANNEL handler because the event
-- fires synchronously right after Blizzard records the line.
-- Returns nil, nil, nil when the API is absent or throws.
local function resolveCommunityChatSource()
  local clubApi = _G.C_Club
  if type(clubApi) ~= "table" or type(clubApi.GetInfoFromLastCommunityChatLine) ~= "function" then
    return nil, nil, nil
  end
  local ok, info = pcall(clubApi.GetInfoFromLastCommunityChatLine)
  if not ok or type(info) ~= "table" then
    return nil, nil, nil
  end
  return info.clubId, info.streamId, info.clubType
end

function EventBridge.RouteGroupEvent(runtime, eventName, ...)
  if runtime == nil or not GROUP_EVENTS[eventName] then
    return false
  end

  -- Unpack the 17-arg Blizzard group chat signature
  local text, playerName, _languageName, channelName, _playerName2, _specialFlags, _zoneChannelID, _channelIndex, channelBaseName, _languageID, lineID, guid, bnSenderID =
    ...

  local conversationID = nil
  if eventName == "CHAT_MSG_BN_CONVERSATION" then
    conversationID = resolveBNConversationID(bnSenderID)
  end

  -- Community chat resolution. Skip guild-type clubs because they also fire
  -- CHAT_MSG_GUILD / CHAT_MSG_OFFICER which are already handled, and we do
  -- not want duplicate threads or messages.
  local clubId, streamId, streamName = nil, nil, nil
  if eventName == "CHAT_MSG_COMMUNITIES_CHANNEL" then
    local cId, sId, clubType = resolveCommunityChatSource()
    if cId == nil or sId == nil then
      return false
    end
    -- Enum.ClubType.Guild == 2. Deduped with CHAT_MSG_GUILD / CHAT_MSG_OFFICER.
    if clubType == 2 then
      return false
    end
    clubId = tostring(cId)
    streamId = tostring(sId)
    -- Prefer the bare stream base name over the full "Club: Stream" channelName.
    if type(channelBaseName) == "string" and channelBaseName ~= "" then
      streamName = channelBaseName
    elseif type(channelName) == "string" and channelName ~= "" then
      streamName = channelName
    end
  end

  -- Resolve sender class/race/faction from guid so the chat bubble can
  -- render a class icon and class-colored name. BN_CONVERSATION events
  -- don't carry a guid (BNet identity instead) — skip for that surface.
  local playerInfo = nil
  if guid and eventName ~= "CHAT_MSG_BN_CONVERSATION" then
    playerInfo = BNetResolver.ResolvePlayerInfo(runtime and runtime.playerInfoByGUID or nil, guid)
  end

  local payload = {
    text = text,
    playerName = playerName,
    lineID = lineID,
    guid = guid,
    bnSenderID = bnSenderID,
    conversationID = conversationID,
    clubId = clubId,
    streamId = streamId,
    streamName = streamName,
    playerInfo = playerInfo,
  }

  if Trace and TRACE_EVENTS[eventName] then
    Trace(
      "EventBridge: "
        .. eventName
        .. " from="
        .. tostring(playerName)
        .. " guid="
        .. tostring(guid)
        .. " lineID="
        .. tostring(lineID)
    )
  end

  local handled = GroupChatIngest.HandleEvent(runtime, eventName, payload)
  if handled and type(runtime.refreshWindow) == "function" then
    runtime.refreshWindow()
  end
  return handled
end

ns.BootstrapEventBridge = EventBridge
return EventBridge
