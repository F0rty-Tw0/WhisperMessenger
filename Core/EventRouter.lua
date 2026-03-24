local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local Queue = ns.LockdownQueue or require("WhisperMessenger.Model.LockdownQueue")
local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")

local Router = {}

local function buildConversationContact(state, payload)
  if payload.channel == "BN" then
    if payload.bnetAccountID == nil then
      return nil, nil
    end

    local contact = Identity.FromBattleNet(payload.bnetAccountID, payload.accountInfo, payload.playerInfo)
    local conversationKey = Identity.BuildConversationKey(state.localProfileId, contact.contactKey)
    return contact, conversationKey
  end

  if payload.playerName == nil then
    return nil, nil
  end

  local contact = Identity.FromWhisper(payload.playerName, payload.guid, payload.playerInfo)
  local conversationKey = Identity.BuildConversationKey(state.localProfileId, contact.contactKey)
  return contact, conversationKey
end

local function buildMessage(eventName, payload, contact, direction, kind, sentAt)
  return {
    id = tostring(payload.lineID or sentAt),
    eventName = eventName,
    direction = direction,
    kind = kind,
    text = payload.text,
    sentAt = sentAt,
    lineID = payload.lineID,
    guid = payload.guid or (contact and contact.guid or nil),
    playerName = (contact and contact.displayName) or payload.playerName,
    channel = (contact and contact.channel) or payload.channel or "WOW",
    bnetAccountID = (contact and contact.bnetAccountID) or payload.bnetAccountID,
    battleTag = (contact and contact.battleTag) or payload.battleTag,
    gameAccountName = (contact and contact.gameAccountName) or payload.gameAccountName,
    className = (contact and contact.className) or payload.className,
    classTag = (contact and contact.classTag) or payload.classTag,
    raceName = (contact and contact.raceName) or payload.raceName,
    raceTag = (contact and contact.raceTag) or payload.raceTag,
    factionName = (contact and contact.factionName) or payload.factionName,
  }
end

function Router.RecordPendingSend(state, target, text)
  local contact
  if target.channel == "BN" then
    contact = Identity.FromBattleNet(target.bnetAccountID, target.accountInfo or target)
  else
    contact = Identity.FromWhisper(target.displayName, target.guid, target)
  end

  local conversationKey = Identity.BuildConversationKey(state.localProfileId, contact.contactKey)

  state.pendingOutgoing[conversationKey] = state.pendingOutgoing[conversationKey] or {}
  table.insert(state.pendingOutgoing[conversationKey], {
    text = text,
    createdAt = state.now(),
  })

  return conversationKey
end

local function handleUnlockedEvent(state, eventName, payload)
  if eventName == "CAN_LOCAL_WHISPER_TARGET_RESPONSE" then
    if payload.guid == nil then
      return nil
    end

    local avail = Availability.FromStatus(payload.status)
    avail.rawStatus = payload.rawStatus
    -- Don't downgrade CanWhisper set by a recent successful whisper.
    -- A whisper exchange proves reachability; the async availability API
    -- may return WrongFaction for cross-realm same-faction players.
    local existing = state.availabilityByGUID[payload.guid]
    if existing and existing.canWhisper and existing.confirmedByWhisper and not avail.canWhisper then
      return existing
    end
    state.availabilityByGUID[payload.guid] = avail
    return avail
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
    local contact, conversationKey = buildConversationContact(state, payload)
    if conversationKey == nil then
      return nil
    end

    local isActive = state.activeConversationKey == conversationKey
    if state.isConversationOpen then
      isActive = state.isConversationOpen(conversationKey) == true
    end
    local sentAt = state.now()

    if eventName == "CHAT_MSG_WHISPER" or eventName == "CHAT_MSG_BN_WHISPER" then
      Store.AppendIncoming(
        state.store,
        conversationKey,
        buildMessage(eventName, payload, contact, "in", "user", sentAt),
        isActive
      )
      -- If someone whispers us, they are clearly online and whisperable
      local guid = payload.guid or (contact and contact.guid or nil)
      if guid then
        local avail = Availability.FromStatus("CanWhisper")
        avail.confirmedByWhisper = true
        state.availabilityByGUID[guid] = avail
      end
    elseif eventName == "CHAT_MSG_WHISPER_INFORM" or eventName == "CHAT_MSG_BN_WHISPER_INFORM" then
      Store.AppendOutgoing(
        state.store,
        conversationKey,
        buildMessage(eventName, payload, contact, "out", "user", sentAt)
      )
      -- Replying means the user saw the conversation; clear unread notification
      Store.MarkRead(state.store, conversationKey)
      -- Our whisper was delivered, so the target is reachable
      local guid = payload.guid or (contact and contact.guid or nil)
      if guid then
        local avail = Availability.FromStatus("CanWhisper")
        avail.confirmedByWhisper = true
        state.availabilityByGUID[guid] = avail
      end
      local pending = state.pendingOutgoing[conversationKey]
      if pending and #pending > 0 then
        table.remove(pending, 1)
      end
    elseif eventName == "CHAT_MSG_AFK" or eventName == "CHAT_MSG_DND" then
      Store.SetActiveStatus(state.store, conversationKey, {
        eventName = eventName,
        text = payload.text,
      })
    else
      Store.AppendIncoming(
        state.store,
        conversationKey,
        buildMessage(eventName, payload, contact, "in", "system", sentAt),
        isActive
      )
    end

    return state.store.conversations[conversationKey]
  end

  return nil
end

function Router.HandleEvent(state, eventName, payload)
  if state.isChatMessagingLocked and state.isChatMessagingLocked() and payload.lineID ~= nil then
    Queue.Enqueue(state.queue, {
      eventName = eventName,
      lineID = payload.lineID,
      payload = payload,
    })
    return { queued = true }
  end

  return handleUnlockedEvent(state, eventName, payload)
end

function Router.ReplayQueued(state, hydrate)
  return Queue.ReplayReady(
    state.queue,
    state.isChatMessagingLocked and state.isChatMessagingLocked() or false,
    function(item)
      if hydrate then
        return hydrate(item)
      end

      return item.payload
    end,
    function(message, item)
      handleUnlockedEvent(state, item.eventName, message)
    end
  )
end

ns.EventRouter = Router

return Router
