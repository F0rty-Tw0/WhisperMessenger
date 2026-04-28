local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")

local PendingOutgoing = {}

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

local function consumeFromQueue(queue, payload, sentAt)
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

function PendingOutgoing.Record(state, target, text)
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

function PendingOutgoing.Consume(state, conversationKey, payload, sentAt)
  local queue = state.pendingOutgoing[conversationKey]
  if consumeFromQueue(queue, payload, sentAt) then
    return true
  end

  for key, candidateQueue in pairs(state.pendingOutgoing) do
    if key ~= conversationKey and consumeFromQueue(candidateQueue, payload, sentAt) then
      return true
    end
  end

  return false
end

ns.EventRouterPendingOutgoing = PendingOutgoing

return PendingOutgoing
