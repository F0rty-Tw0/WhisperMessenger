local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local function loadModule(name, key)
  if ns[key] then
    return ns[key]
  end

  local ok, loaded = pcall(require, name)
  if ok then
    return loaded
  end

  error(key .. " module not available")
end

local Identity = loadModule("WhisperMessenger.Model.Identity", "Identity")
local Store = loadModule("WhisperMessenger.Model.ConversationStore", "ConversationStore")
local Queue = loadModule("WhisperMessenger.Model.LockdownQueue", "LockdownQueue")
local Availability = loadModule("WhisperMessenger.Transport.Availability", "Availability")

local Router = {}

local function buildConversationContact(state, payload)
  if payload.channel == "BN" then
    if payload.bnetAccountID == nil then
      return nil, nil
    end

    local contact = Identity.FromBattleNet(payload.bnetAccountID, payload.accountInfo)
    local conversationKey = Identity.BuildConversationKey(state.localProfileId, contact.contactKey)
    return contact, conversationKey
  end

  if payload.playerName == nil then
    return nil, nil
  end

  local contact = Identity.FromWhisper(payload.playerName, payload.guid)
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
    gameAccountName = (contact and contact.gameAccountName) or payload.gameAccountName,
  }
end

function Router.RecordPendingSend(state, target, text)
  local contact
  if target.channel == "BN" then
    contact = Identity.FromBattleNet(target.bnetAccountID, target.accountInfo or target)
  else
    contact = Identity.FromWhisper(target.displayName, target.guid)
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

    state.availabilityByGUID[payload.guid] = Availability.FromStatus(payload.status)
    return state.availabilityByGUID[payload.guid]
  end

  if eventName == "CHAT_MSG_WHISPER" or eventName == "CHAT_MSG_WHISPER_INFORM" or eventName == "CHAT_MSG_AFK" or eventName == "CHAT_MSG_DND" or eventName == "CHAT_MSG_BN_WHISPER" or eventName == "CHAT_MSG_BN_WHISPER_INFORM" or eventName == "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE" then
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
      Store.AppendIncoming(state.store, conversationKey, buildMessage(eventName, payload, contact, "in", "user", sentAt), isActive)
    elseif eventName == "CHAT_MSG_WHISPER_INFORM" or eventName == "CHAT_MSG_BN_WHISPER_INFORM" then
      Store.AppendOutgoing(state.store, conversationKey, buildMessage(eventName, payload, contact, "out", "user", sentAt))
      local pending = state.pendingOutgoing[conversationKey]
      if pending and #pending > 0 then
        table.remove(pending, 1)
      end
    else
      Store.AppendIncoming(state.store, conversationKey, buildMessage(eventName, payload, contact, "in", "system", sentAt), isActive)
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
