local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local Queue = ns.LockdownQueue or require("WhisperMessenger.Model.LockdownQueue")
local Availability = ns.Availability or require("WhisperMessenger.Transport.Availability")

local Router = {}

local function checkCensored(lineID)
  local chatApi = _G.C_ChatInfo
  if chatApi == nil or type(chatApi.IsChatLineCensored) ~= "function" then
    return nil
  end
  if lineID == nil then
    return nil
  end
  local ok, censored = pcall(chatApi.IsChatLineCensored, lineID)
  if ok and censored == true then
    return true
  end
  return nil
end

local function buildConversationContact(state, payload)
  if payload.channel == "BN" then
    if payload.bnetAccountID == nil then
      return nil, nil
    end

    local contact = Identity.FromBattleNet(payload.bnetAccountID, payload.accountInfo, payload.playerInfo)
    if contact.canonicalName == "" then
      return nil, nil
    end
    local conversationKey = Identity.BuildConversationKey(state.localProfileId, contact.contactKey)
    return contact, conversationKey
  end

  -- Only a nil-check here: comparing a tainted chat payload against a literal
  -- string trips Blizzard's secret-string protection. We defer the "empty
  -- name" rejection to the canonicalName check below — normalizeName pcalls
  -- Ambiguate/string.lower, so tainted names degrade to "" safely.
  if payload.playerName == nil then
    return nil, nil
  end

  local contact = Identity.FromWhisper(payload.playerName, payload.guid, payload.playerInfo)
  if contact.canonicalName == "" then
    return nil, nil
  end
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
    isCensored = payload.isCensored or checkCensored(payload.lineID),
  }
end

local PENDING_MATCH_WINDOW_SECONDS = 15

local function canonicalName(name, guid)
  if name == nil or name == "" then
    return ""
  end
  local contact = Identity.FromWhisper(name, guid, {})
  return contact.canonicalName or ""
end

local function baseName(canonical)
  if canonical == nil or canonical == "" then
    return ""
  end
  return string.match(canonical, "^([^-]+)") or canonical
end

local function namesLikelySame(leftName, leftGuid, rightName, rightGuid)
  local leftCanonical = canonicalName(leftName, leftGuid)
  local rightCanonical = canonicalName(rightName, rightGuid)
  if leftCanonical == "" or rightCanonical == "" then
    return false
  end
  if leftCanonical == rightCanonical then
    return true
  end
  return baseName(leftCanonical) == baseName(rightCanonical)
end

local function pendingMatchesOutgoing(pending, payload, sentAt)
  if type(pending) ~= "table" then
    return false
  end

  local payloadChannel = payload.channel or "WOW"
  if (pending.channel or "WOW") ~= payloadChannel then
    return false
  end
  if pending.text ~= nil and payload.text ~= nil and pending.text ~= payload.text then
    return false
  end

  if type(sentAt) == "number" and type(pending.createdAt) == "number" then
    if sentAt < pending.createdAt or (sentAt - pending.createdAt) > PENDING_MATCH_WINDOW_SECONDS then
      return false
    end
  end

  if payloadChannel == "BN" then
    if pending.bnetAccountID ~= nil and payload.bnetAccountID ~= nil then
      return pending.bnetAccountID == payload.bnetAccountID
    end
    return namesLikelySame(pending.displayName or pending.target, pending.guid, payload.playerName, payload.guid)
  end

  if pending.guid ~= nil and payload.guid ~= nil then
    return pending.guid == payload.guid
  end
  return namesLikelySame(pending.displayName or pending.target, pending.guid, payload.playerName, payload.guid)
end

local function isPendingExpired(pending, sentAt)
  if type(sentAt) ~= "number" or type(pending) ~= "table" or type(pending.createdAt) ~= "number" then
    return false
  end
  return sentAt - pending.createdAt > PENDING_MATCH_WINDOW_SECONDS
end

local function consumeFromPendingQueue(queue, payload, sentAt)
  if type(queue) ~= "table" or #queue == 0 then
    return false
  end

  for index = #queue, 1, -1 do
    if isPendingExpired(queue[index], sentAt) then
      table.remove(queue, index)
    end
  end

  for index = 1, #queue do
    if pendingMatchesOutgoing(queue[index], payload, sentAt) then
      table.remove(queue, index)
      return true
    end
  end

  return false
end

local function consumePendingOutgoing(state, conversationKey, payload, sentAt)
  local queue = state.pendingOutgoing[conversationKey]
  if consumeFromPendingQueue(queue, payload, sentAt) then
    return true
  end

  for key, candidateQueue in pairs(state.pendingOutgoing) do
    if key ~= conversationKey and consumeFromPendingQueue(candidateQueue, payload, sentAt) then
      return true
    end
  end

  return false
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
    channel = target.channel or "WOW",
    guid = target.guid,
    bnetAccountID = target.bnetAccountID,
    displayName = target.displayName,
    target = target.target,
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
    local outgoingFromPendingSend = false

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
      outgoingFromPendingSend = consumePendingOutgoing(state, conversationKey, payload, sentAt)
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

    local conversation = state.store.conversations[conversationKey]
    if conversation then
      conversation.conversationKey = conversationKey
    end
    return conversation, { outgoingFromPendingSend = outgoingFromPendingSend }
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
