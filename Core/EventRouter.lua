local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")
local PendingOutgoing = ns.EventRouterPendingOutgoing or require("WhisperMessenger.Core.EventRouter.PendingOutgoing")
local SecretString = ns.GroupChatIngestSecretString or require("WhisperMessenger.Core.Ingest.GroupChatIngest.SecretString")
local FailedWhisper = ns.EventRouterFailedWhisper or require("WhisperMessenger.Core.EventRouter.FailedWhisper")
local PresenceCache = ns.PresenceCache or require("WhisperMessenger.Model.PresenceCache")
local IncomingFilter = ns.IncomingFilter or require("WhisperMessenger.Core.Ingest.IncomingFilter")
local WhisperMessage = ns.EventRouterWhisperMessage or require("WhisperMessenger.Core.EventRouter.WhisperMessage")
local AddonMessage = ns.EventRouterAddonMessage or require("WhisperMessenger.Core.EventRouter.AddonMessage")
local IncomingWhisper = ns.EventRouterIncomingWhisper or require("WhisperMessenger.Core.EventRouter.IncomingWhisper")
local OutgoingWhisper = ns.EventRouterOutgoingWhisper or require("WhisperMessenger.Core.EventRouter.OutgoingWhisper")
local CharacterRedirect = ns.EventRouterCharacterRedirect or require("WhisperMessenger.Core.EventRouter.CharacterRedirect")

local buildConversationContact = WhisperMessage.BuildConversationContact
local buildMessage = WhisperMessage.BuildMessage
local conversationWithKey = WhisperMessage.ConversationWithKey
local isOpen = WhisperMessage.IsOpen
local isWhisperProofFresh = WhisperMessage.IsWhisperProofFresh

local Router = {}
Router._isSecretString = SecretString.IsSecretString

function Router.RecordPendingSend(state, target, text, metadata)
  return PendingOutgoing.Record(state, target, text, metadata)
end

local function handleAvailabilityResponse(state, payload)
  if payload.guid == nil then
    return nil
  end

  local avail = Availability.FromStatus(payload.status)
  avail.rawStatus = payload.rawStatus
  -- A whisper exchange proves reachability, so keep it over the ambiguous
  -- WrongFaction, and over Offline for WHISPER_PROOF_SECONDS after the
  -- whisper. A guild/community roster showing them offline always wins.
  local existing = state.availabilityByGUID[payload.guid]
  local now = state.now and state.now() or 0
  if
    existing
    and existing.canWhisper
    and existing.confirmedByWhisper
    and PresenceCache.GetPresence(payload.guid) ~= "offline"
    and (avail.status == "WrongFaction" or (avail.status == "Offline" and isWhisperProofFresh(existing, now)))
  then
    return existing
  end
  state.availabilityByGUID[payload.guid] = avail
  if (existing == nil or existing.status ~= avail.status) and type(state.onAvailabilityChanged) == "function" then
    state.onAvailabilityChanged(payload.guid)
  end
  return avail
end

local function handleWhisperEvent(state, eventName, payload)
  local contact, conversationKey = buildConversationContact(state, payload)
  if conversationKey == nil then
    return nil
  end
  -- Before the open-chat check: a fold may swap the open chat to the friend's.
  local mergeEntry, opensNewChat
  conversationKey, mergeEntry, opensNewChat = CharacterRedirect.Resolve(state, contact, conversationKey, payload)

  local isActive = isOpen(state, conversationKey)
  local sentAt = payload.replayedAt or state.now()

  if eventName == "CHAT_MSG_WHISPER" or eventName == "CHAT_MSG_BN_WHISPER" then
    return IncomingWhisper.Handle(state, eventName, payload, contact, conversationKey, isActive, sentAt, mergeEntry, opensNewChat)
  elseif eventName == "CHAT_MSG_WHISPER_INFORM" or eventName == "CHAT_MSG_BN_WHISPER_INFORM" then
    return OutgoingWhisper.Handle(state, payload, contact, conversationKey, sentAt, mergeEntry)
  elseif eventName == "CHAT_MSG_AFK" or eventName == "CHAT_MSG_DND" then
    Store.SetActiveStatus(state.store, conversationKey, {
      eventName = eventName,
      text = payload.text,
      sentAt = sentAt,
      lineID = payload.lineID,
    })
  else
    Store.AppendIncoming(state.store, conversationKey, buildMessage(state, payload, contact, "in", "system", sentAt), isActive)
  end

  return conversationWithKey(state, conversationKey), { outgoingFromPendingSend = false }
end

local function handleUnlockedEvent(state, eventName, payload)
  if type(payload) ~= "table" or SecretString.PayloadHasSecretFields(payload, Router._isSecretString) then
    return nil
  end
  if eventName == "CHAT_MSG_ADDON" then
    return AddonMessage.HandleCharacter(state, payload)
  end

  if eventName == "BN_CHAT_MSG_ADDON" then
    return AddonMessage.HandleBattleNet(state, payload)
  end

  if eventName == "CHAT_MSG_SYSTEM" then
    return FailedWhisper.Handle(state, payload.text)
  end

  if eventName == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
    return handleAvailabilityResponse(state, payload)
  end

  if
    eventName == "CHAT_MSG_WHISPER"
    or eventName == "CHAT_MSG_WHISPER_INFORM"
    or eventName == "CHAT_MSG_AFK"
    or eventName == "CHAT_MSG_DND"
    or eventName == "CHAT_MSG_BN_WHISPER"
    or eventName == "CHAT_MSG_BN_WHISPER_INFORM"
    or eventName == "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE"
  then
    return handleWhisperEvent(state, eventName, payload)
  end

  return nil
end

-- Only character whispers are filtered: the ignore key is a character name.
function Router.HandleEvent(state, eventName, payload)
  if eventName == "CHAT_MSG_WHISPER" and type(payload) == "table" then
    if IncomingFilter.Evaluate(state, "whisper", payload.playerName, payload.text, payload.lineID, eventName) ~= "pass" then
      return nil
    end
  end
  return handleUnlockedEvent(state, eventName, payload)
end

ns.EventRouter = Router

return Router
