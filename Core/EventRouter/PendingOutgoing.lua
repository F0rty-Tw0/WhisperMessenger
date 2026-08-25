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

local function compareBNetAccountIDs(left, right)
  local bothPresent = left ~= nil and right ~= nil
  return bothPresent, bothPresent and left == right
end

local function matchBNetAccountIDs(left, right)
  local ok, bothPresent, matches = pcall(compareBNetAccountIDs, left, right)
  if not ok then
    return true, false
  end
  return bothPresent, matches
end

local function pendingTargetMatches(pending, payload, sentAt)
  if type(pending) ~= "table" then
    return false
  end

  local payloadChannel = payload.channel or "WOW"
  if (pending.channel or "WOW") ~= payloadChannel then
    return false
  end

  if type(sentAt) == "number" and type(pending.createdAt) == "number" then
    if sentAt < pending.createdAt or (sentAt - pending.createdAt) > PENDING_MATCH_WINDOW_SECONDS then
      return false
    end
  end

  if payloadChannel == "BN" then
    local bothPresent, matches = matchBNetAccountIDs(pending.bnetAccountID, payload.bnetAccountID)
    if bothPresent then
      return matches
    end
    return namesLikelySame(pending.displayName or pending.target, pending.guid, payload.playerName, payload.guid)
  end

  if pending.guid ~= nil and payload.guid ~= nil then
    return pending.guid == payload.guid
  end
  return namesLikelySame(pending.displayName or pending.target, pending.guid, payload.playerName, payload.guid)
end

local function pendingMatchesOutgoing(pending, payload, sentAt)
  if not pendingTargetMatches(pending, payload, sentAt) then
    return false
  end
  if pending.text ~= nil and payload.text ~= nil and pending.text ~= payload.text then
    return false
  end
  return true
end

local function isPendingExpired(pending, sentAt)
  if type(sentAt) ~= "number" or type(pending) ~= "table" or type(pending.createdAt) ~= "number" then
    return false
  end
  return sentAt - pending.createdAt > PENDING_MATCH_WINDOW_SECONDS
end

local function pruneExpiredQueues(state, sentAt)
  if type(state) ~= "table" or type(state.pendingOutgoing) ~= "table" then
    return
  end

  for key, queue in pairs(state.pendingOutgoing) do
    if type(queue) == "table" then
      for index = #queue, 1, -1 do
        if isPendingExpired(queue[index], sentAt) then
          table.remove(queue, index)
        end
      end
      if #queue == 0 then
        state.pendingOutgoing[key] = nil
      end
    end
  end
end

local function consumeFromQueue(queue, payload, sentAt, matchFn)
  if type(queue) ~= "table" or #queue == 0 then
    return nil
  end

  for index = #queue, 1, -1 do
    if isPendingExpired(queue[index], sentAt) then
      table.remove(queue, index)
    end
  end

  for index = 1, #queue do
    if matchFn(queue[index], payload, sentAt) then
      return table.remove(queue, index)
    end
  end

  return nil
end

-- Try a matcher (strict or soft) across the conversation's queue first, then
-- spill into other queues. Returns the consumed entry or nil.
local function consumeWithMatcher(state, conversationKey, payload, sentAt, matchFn)
  local entry = consumeFromQueue(state.pendingOutgoing[conversationKey], payload, sentAt, matchFn)
  if entry ~= nil then
    return entry
  end
  for key, candidateQueue in pairs(state.pendingOutgoing) do
    if key ~= conversationKey then
      entry = consumeFromQueue(candidateQueue, payload, sentAt, matchFn)
      if entry ~= nil then
        return entry
      end
    end
  end
  return nil
end

function PendingOutgoing.Record(state, target, text, metadata)
  local contact
  if target.channel == "BN" then
    contact = Identity.FromBattleNet(target.bnetAccountID, target.accountInfo or target)
  else
    contact = Identity.FromWhisper(target.displayName, target.guid, target)
  end

  local conversationKey = Identity.BuildConversationKey(state.localProfileId, contact.contactKey)
  local now = state.now()
  pruneExpiredQueues(state, now)

  metadata = type(metadata) == "table" and metadata or {}
  state.pendingOutgoing[conversationKey] = state.pendingOutgoing[conversationKey] or {}
  table.insert(state.pendingOutgoing[conversationKey], {
    text = text,
    createdAt = now,
    channel = target.channel or "WOW",
    guid = target.guid,
    bnetAccountID = target.bnetAccountID,
    displayName = target.displayName,
    target = target.target,
    wireId = metadata.wireId,
    reactionControl = metadata.reactionControl,
  })

  return conversationKey
end

-- Resolve a CHAT_MSG_*_INFORM event against the pending queue.
--
-- WoW Classic's character whisper protocol can strip a real outgoing quest
-- hyperlink down to a bare label (no envelope, no brackets, no id) by the
-- time it echoes back, so the echo text alone can't be matched against the
-- pending text. We try a strict (text-equal) match first, then fall back to
-- a soft (channel + target + timing) match. In both cases the matched entry
-- is removed so a later INFORM doesn't surface a stale pending entry.
--
-- Returns `(fromPending, pendingText, entry)`:
--   * `fromPending` — whether ANY pending entry matched.
--   * `pendingText` — the locally captured text we tried to send.
--   * `entry` — the consumed pending record for optional send metadata.
function PendingOutgoing.Resolve(state, conversationKey, payload, sentAt)
  local entry = consumeWithMatcher(state, conversationKey, payload, sentAt, pendingMatchesOutgoing)
  if entry == nil then
    entry = consumeWithMatcher(state, conversationKey, payload, sentAt, pendingTargetMatches)
  end
  if entry == nil then
    return false, nil
  end
  return true, entry.text, entry
end

-- Backwards-compat wrapper: strict (text-equal) match only. Resolve is the
-- preferred entry point; this helper exists for callers that only need the
-- boolean "was-from-pending" signal and don't want soft-match behavior.
function PendingOutgoing.Consume(state, conversationKey, payload, sentAt)
  local entry = consumeWithMatcher(state, conversationKey, payload, sentAt, pendingMatchesOutgoing)
  return entry ~= nil
end

ns.EventRouterPendingOutgoing = PendingOutgoing

return PendingOutgoing
