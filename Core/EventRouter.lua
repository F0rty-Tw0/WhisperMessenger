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

local function buildConversationKey(state, playerName, guid)
  local contact = Identity.FromWhisper(playerName, guid)
  local conversationKey = Identity.BuildConversationKey(state.localProfileId, contact.contactKey)
  return contact, conversationKey
end

local function buildMessage(eventName, payload, direction, kind, sentAt)
  return {
    id = tostring(payload.lineID or sentAt),
    eventName = eventName,
    direction = direction,
    kind = kind,
    text = payload.text,
    sentAt = sentAt,
    lineID = payload.lineID,
    guid = payload.guid,
    playerName = payload.playerName,
    channel = payload.channel or "WOW",
  }
end

function Router.RecordPendingSend(state, target, text)
  local contact = Identity.FromWhisper(target, nil)
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
    state.availabilityByGUID[payload.guid] = Availability.FromStatus(payload.status)
    return state.availabilityByGUID[payload.guid]
  end

  if eventName == "CHAT_MSG_WHISPER" or eventName == "CHAT_MSG_WHISPER_INFORM" or eventName == "CHAT_MSG_AFK" or eventName == "CHAT_MSG_DND" then
    local _, conversationKey = buildConversationKey(state, payload.playerName, payload.guid)
    local isActive = state.activeConversationKey == conversationKey
    local sentAt = state.now()

    if eventName == "CHAT_MSG_WHISPER" then
      Store.AppendIncoming(state.store, conversationKey, buildMessage(eventName, payload, "in", "user", sentAt), isActive)
    elseif eventName == "CHAT_MSG_WHISPER_INFORM" then
      Store.AppendOutgoing(state.store, conversationKey, buildMessage(eventName, payload, "out", "user", sentAt))
      local pending = state.pendingOutgoing[conversationKey]
      if pending and #pending > 0 then
        table.remove(pending, 1)
      end
    else
      Store.AppendIncoming(state.store, conversationKey, buildMessage(eventName, payload, "in", "system", sentAt), isActive)
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
