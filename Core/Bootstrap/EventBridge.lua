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

-- stylua: ignore start
local Registration = ns.BootstrapEventBridgeRegistration or require("WhisperMessenger.Core.Bootstrap.EventBridge.Registration")
local LivePayload = ns.BootstrapEventBridgeLivePayload or require("WhisperMessenger.Core.Bootstrap.EventBridge.LivePayload")
local GroupRouter = ns.BootstrapEventBridgeGroupRouter or require("WhisperMessenger.Core.Bootstrap.EventBridge.GroupRouter")
-- stylua: ignore end

local EventBridge = {}

-- Delegate registration functions to the Registration submodule.
EventBridge.RegisterLiveEvents = Registration.RegisterLiveEvents
EventBridge.UnregisterLiveEvents = Registration.UnregisterLiveEvents
EventBridge.RegisterChannelEvents = Registration.RegisterChannelEvents
EventBridge.UnregisterChannelEvents = Registration.UnregisterChannelEvents
EventBridge.RegisterGroupEvents = Registration.RegisterGroupEvents
EventBridge.UnregisterGroupEvents = Registration.UnregisterGroupEvents
EventBridge.RegisterSuspendableLifecycleEvents = Registration.RegisterSuspendableLifecycleEvents
EventBridge.UnregisterSuspendableLifecycleEvents = Registration.UnregisterSuspendableLifecycleEvents

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

function EventBridge.RouteLiveEvent(runtime, refreshWindow, eventName, ...)
  if runtime == nil then
    return nil
  end
  local payload = LivePayload.Build(runtime, eventName, ...)
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
    local inGroupsTab = runtime.window and type(runtime.window.getTabMode) == "function" and runtime.window.getTabMode() == "groups"
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
    -- Unlike incoming whispers (which stay quiet to avoid yanking the user off
    -- a group selection they chose), outgoing whispers fire the auto-open path
    -- even when Groups is active — the user initiated the whisper and expects
    -- to see the conversation they just started. The openAndSelect handler
    -- then force-switches to the Whispers tab.
    if
      runtime.accountState
      and runtime.accountState.settings
      and runtime.accountState.settings.autoOpenOutgoing == true
      and runtime.onAutoOpenOutgoing
      and type(_G.InCombatLockdown) == "function"
      and not _G.InCombatLockdown()
      and not (resultMeta and resultMeta.outgoingFromPendingSend == true)
    then
      runtime.onAutoOpenOutgoing(result.conversationKey)
    end
  end
  if refreshWindow then
    refreshWindow()
  end
  return result
end

function EventBridge.RouteGroupEvent(runtime, eventName, ...)
  return GroupRouter.RouteGroupEvent(runtime, eventName, TRACE_EVENTS, ...)
end

ns.BootstrapEventBridge = EventBridge
return EventBridge
