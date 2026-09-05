local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local EventRouter = ns.EventRouter or require("WhisperMessenger.Core.EventRouter")
local SoundPlayer = ns.SoundPlayer or require("WhisperMessenger.Core.SoundPlayer")
local ChannelMessageStore = ns.ChannelMessageStore or require("WhisperMessenger.Model.ChannelMessageStore")
local LivePresence = ns.LivePresence or require("WhisperMessenger.Model.LivePresence")


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

-- A typing indicator expires on its own; nothing else would redraw the
-- window at that moment, so schedule one refresh just past the TTL. At most
-- one pending timer is kept per conversation: while the peer keeps typing
-- (extending the TTL on every packet), the timer just re-arms for the new
-- remaining time instead of stacking a fresh timer per packet.
local TYPING_EXPIRY_GRACE = 0.2
local function scheduleTypingExpiry(runtime, refreshWindow, conversationKey)
  local timer = _G.C_Timer
  if timer == nil or type(timer.After) ~= "function" then
    return
  end
  runtime.typingExpiryPending = runtime.typingExpiryPending or {}
  if runtime.typingExpiryPending[conversationKey] then
    return
  end
  local function fire()
    local now = runtime.now and runtime.now() or 0
    local remaining = LivePresence.TypingRemaining(runtime, conversationKey, now)
    if remaining > 0 then
      timer.After(remaining + TYPING_EXPIRY_GRACE, fire)
    else
      runtime.typingExpiryPending[conversationKey] = nil
      refreshWindow(conversationKey)
    end
  end
  runtime.typingExpiryPending[conversationKey] = true
  timer.After(LivePresence.TYPING_TTL + TYPING_EXPIRY_GRACE, fire)
end

local function applyIncomingEffects(runtime, result)
  if runtime.accountState and runtime.accountState.settings and runtime.accountState.settings.playSoundOnWhisper == true then
    SoundPlayer.Play(runtime.accountState.settings)
  end
  if result and result.conversationKey then
    runtime.lastIncomingWhisperKey = result.conversationKey
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
end

function EventBridge.RouteLiveEvent(runtime, refreshWindow, eventName, ...)
  if runtime == nil then
    return nil
  end
  if eventName == "CHAT_MSG_ADDON" or eventName == "BN_CHAT_MSG_ADDON" then
    local prefix = ...
    if prefix ~= "WMRX" and prefix ~= "WMQL" then
      return nil
    end
  end
  local payload = LivePayload.Build(runtime, eventName, ...)
  runtime.onReactionFallbackDegraded = function(degradedConversation)
    if degradedConversation == nil then
      return
    end
    applyIncomingEffects(runtime, degradedConversation)
    if refreshWindow and degradedConversation.conversationKey then
      refreshWindow(degradedConversation.conversationKey)
    end
  end

  local result, resultMeta = EventRouter.HandleEvent(runtime, eventName, payload)
  local convertedReactionControl = resultMeta and resultMeta.reactionControl == true
  local changedSetReaction = type(resultMeta) == "table" and resultMeta.reactionChanged == true and resultMeta.reactionOperation == "set"
  local shouldApplyIncomingEffects = result
    and ((INCOMING_WHISPER_EVENTS[eventName] and not convertedReactionControl) or (convertedReactionControl and changedSetReaction))
  if shouldApplyIncomingEffects then
    applyIncomingEffects(runtime, result)
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
  if refreshWindow and result and result.conversationKey then
    local typingMeta = type(resultMeta) == "table" and resultMeta.presence == "typing" and resultMeta or nil
    if not (typingMeta and typingMeta.typingChanged == false) then
      refreshWindow(result.conversationKey)
    end
    if typingMeta and typingMeta.typingActive == true then
      scheduleTypingExpiry(runtime, refreshWindow, result.conversationKey)
    end
  end
  return result
end

function EventBridge.RouteGroupEvent(runtime, eventName, ...)
  return GroupRouter.RouteGroupEvent(runtime, eventName, ...)
end

ns.BootstrapEventBridge = EventBridge
return EventBridge
