local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

local GroupChatIngest = {}

-- Map from event name to channel type constant
local EVENT_TO_CHANNEL = {
  CHAT_MSG_PARTY = ChannelType.PARTY,
  CHAT_MSG_PARTY_LEADER = ChannelType.PARTY,
  CHAT_MSG_INSTANCE_CHAT = ChannelType.INSTANCE_CHAT,
  CHAT_MSG_INSTANCE_CHAT_LEADER = ChannelType.INSTANCE_CHAT,
  CHAT_MSG_RAID = ChannelType.RAID,
  CHAT_MSG_RAID_LEADER = ChannelType.RAID,
  CHAT_MSG_RAID_WARNING = ChannelType.RAID,
  CHAT_MSG_GUILD = ChannelType.GUILD,
  CHAT_MSG_OFFICER = ChannelType.OFFICER,
  CHAT_MSG_BN_CONVERSATION = ChannelType.BN_CONVERSATION,
  CHAT_MSG_COMMUNITIES_CHANNEL = ChannelType.COMMUNITY,
}

-- Events that carry a "leader" flag
local LEADER_EVENTS = {
  CHAT_MSG_PARTY_LEADER = true,
  CHAT_MSG_INSTANCE_CHAT_LEADER = true,
  CHAT_MSG_RAID_LEADER = true,
  CHAT_MSG_RAID_WARNING = true,
}

-- Contact key prefix per channel type (for singleton group channels)
local CHANNEL_CONTACT_KEY = {
  [ChannelType.PARTY] = "PARTY::",
  [ChannelType.INSTANCE_CHAT] = "INSTANCE::",
  [ChannelType.RAID] = "RAID::",
  [ChannelType.GUILD] = "GUILD::",
  [ChannelType.OFFICER] = "OFFICER::",
}

local function localSenderClassTag()
  if type(_G.UnitClass) ~= "function" then
    return nil
  end
  local ok, _, classTag = pcall(_G.UnitClass, "player")
  if ok and type(classTag) == "string" and classTag ~= "" then
    return classTag
  end
  return nil
end

local function localSenderName()
  if type(_G.UnitName) ~= "function" then
    return nil
  end
  local ok, name = pcall(_G.UnitName, "player")
  if ok and type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

local function buildMessage(eventName, payload, direction, channel, sentAt, isLeader)
  local playerInfo = payload.playerInfo or {}
  local senderClassTag
  local senderName
  if direction == "out" then
    -- Freeze the sending character's class and name so the bubble icon and
    -- "You — <char>" label survive relogging. Prefer already-resolved fields
    -- from the payload over live API calls.
    senderClassTag = playerInfo.classTag or localSenderClassTag()
    -- Use the live player's short name, not payload.playerName. Group chat
    -- events deliver "Name-Realm"; SenderLabel compares against the live
    -- UnitName("player") which is the short form, so we normalize here.
    senderName = localSenderName()
  end
  local msg = {
    id = tostring(payload.lineID or sentAt),
    eventName = eventName,
    direction = direction,
    kind = "user",
    text = payload.text,
    sentAt = sentAt,
    lineID = payload.lineID,
    guid = payload.guid,
    playerName = payload.playerName,
    channel = channel,
    bnetAccountID = payload.bnSenderID,
    className = playerInfo.className,
    classTag = playerInfo.classTag,
    senderClassTag = senderClassTag,
    senderName = senderName,
    raceName = playerInfo.raceName,
    raceTag = playerInfo.raceTag,
    factionName = playerInfo.factionName,
  }
  -- Only attach isLeader for PARTY/INSTANCE messages that have the concept
  if isLeader ~= nil then
    msg.isLeader = isLeader
  end
  return msg
end

-- Resolve the local player's GUID. Prefer the cached state value; fall back
-- to live _G.UnitGUID("player") so direction detection works even when the
-- runtime was created before player identity was available (ADDON_LOADED
-- fires before PLAYER_ENTERING_WORLD on a cold boot).
local function resolveLocalPlayerGuid(state)
  if type(state.localPlayerGuid) == "string" and state.localPlayerGuid ~= "" then
    return state.localPlayerGuid
  end
  if type(_G.UnitGUID) == "function" then
    local ok, guid = pcall(_G.UnitGUID, "player")
    if ok and type(guid) == "string" and guid ~= "" then
      state.localPlayerGuid = guid
      return guid
    end
  end
  return nil
end

-- In 12.0 Midnight, event payloads inside encounters / restricted actions
-- can carry "secret string" values (GUID, sender name, message text). Any
-- operation on them from an addon-tainted frame (==, string.lower,
-- table.concat) throws `a secret string value tainted by 'WhisperMessenger'`.
-- Detect via pcall on a cheap comparison; if it throws the value is secret.
local function rawStringCompare(value)
  return value == ""
end

local function isSecretString(value)
  if value == nil then
    return false
  end
  if type(value) ~= "string" then
    return false
  end
  local ok = pcall(rawStringCompare, value)
  return not ok
end

local function payloadHasSecretFields(payload)
  -- Dispatch through the module table so tests can swap the detector
  -- (the real WoW "secret string" type cannot be simulated from plain Lua).
  local detect = GroupChatIngest._isSecretString or isSecretString
  if detect(payload.text) then
    return true
  end
  if detect(payload.playerName) then
    return true
  end
  if detect(payload.guid) then
    return true
  end
  return false
end

local function rawGuidEqual(a, b)
  return a == b
end

local function compareGuids(a, b)
  if a == nil or b == nil then
    return false
  end
  local ok, equal = pcall(rawGuidEqual, a, b)
  return ok and equal == true
end

local function resolveDirection(eventName, payload, state)
  if eventName == "CHAT_MSG_BN_CONVERSATION" then
    -- No guid on BN conversation events; use bnetAccountID comparison
    if state.localBnetAccountID ~= nil and payload.bnSenderID == state.localBnetAccountID then
      return "out"
    end
    return "in"
  end

  -- For every other group surface: compare guid to the local player's guid.
  local localGuid = resolveLocalPlayerGuid(state)
  if compareGuids(payload.guid, localGuid) then
    return "out"
  end
  return "in"
end

-- HandleEvent processes one of the 5 group chat events.
-- Returns true when the event was recognized and routed; false otherwise.
function GroupChatIngest.HandleEvent(state, eventName, payload)
  local channel = EVENT_TO_CHANNEL[eventName]
  if channel == nil then
    return false
  end

  -- Drop messages carrying 12.0 "secret string" fields. Storing them would
  -- poison every downstream read (ConversationSnapshot search text, bubble
  -- rendering, etc.). Blizzard's default chat frame still renders the line
  -- via its secure path, so the user doesn't lose visibility.
  if payloadHasSecretFields(payload) then
    return false
  end

  -- BN_CONVERSATION requires a conversationID to build a stable key
  if channel == ChannelType.BN_CONVERSATION then
    if payload.conversationID == nil then
      return false
    end
    local conversationKey =
      Identity.BuildConversationKey(state.localProfileId, "BNCONV::" .. tostring(payload.conversationID))
    local direction = resolveDirection(eventName, payload, state)
    local sentAt = (state.now and state.now()) or 0
    local msg = buildMessage(eventName, payload, direction, channel, sentAt, nil)

    if direction == "out" then
      Store.AppendOutgoing(state.store, conversationKey, msg)
    else
      local isActive = state.activeConversationKey == conversationKey
      Store.AppendIncoming(state.store, conversationKey, msg, isActive)
    end

    -- Stamp the conversation record with its key (mirrors EventRouter pattern)
    if state.store.conversations[conversationKey] then
      state.store.conversations[conversationKey].conversationKey = conversationKey
    end

    return true
  end

  -- COMMUNITY: keyed by (clubId, streamId). Receive-only — Blizzard blocks
  -- C_Club.SendMessage for addons since patch 8.1.0.
  if channel == ChannelType.COMMUNITY then
    if payload.clubId == nil or payload.streamId == nil then
      return false
    end
    local contactKey = "COMMUNITY::" .. tostring(payload.clubId) .. "::" .. tostring(payload.streamId)
    local conversationKey = Identity.BuildConversationKey(state.localProfileId, contactKey)
    local direction = resolveDirection(eventName, payload, state)
    local sentAt = (state.now and state.now()) or 0
    local msg = buildMessage(eventName, payload, direction, channel, sentAt, nil)

    if direction == "out" then
      Store.AppendOutgoing(state.store, conversationKey, msg)
    else
      local isActive = state.activeConversationKey == conversationKey
      Store.AppendIncoming(state.store, conversationKey, msg, isActive)
    end

    if state.store.conversations[conversationKey] then
      local conv = state.store.conversations[conversationKey]
      conv.conversationKey = conversationKey
      -- Use the stream's base name as the sticky title so the row shows
      -- "General" or "Trade" instead of the generic "Community" label.
      if type(payload.streamName) == "string" and payload.streamName ~= "" then
        conv.title = payload.streamName
      end
    end

    return true
  end

  -- PARTY / INSTANCE_CHAT / RAID / OFFICER: singleton per-character.
  -- GUILD is special: when we can resolve the player's live guild name,
  -- the key becomes account-wide (all characters in the same guild
  -- share the same conversation). Falls back to a per-character key
  -- when the name is unavailable.
  local contactKeyPrefix = CHANNEL_CONTACT_KEY[channel]
  local guildName = nil
  if channel == ChannelType.GUILD then
    local getGuildInfo = _G.GetGuildInfo
    if type(getGuildInfo) == "function" then
      local ok, name = pcall(getGuildInfo, "player")
      if ok and type(name) == "string" and name ~= "" then
        guildName = name
        contactKeyPrefix = "GUILD::" .. name
      end
    end
  end

  local conversationKey = Identity.BuildConversationKey(state.localProfileId, contactKeyPrefix)
  local direction = resolveDirection(eventName, payload, state)
  local sentAt = (state.now and state.now()) or 0
  local isLeader = LEADER_EVENTS[eventName] == true and true or false
  local msg = buildMessage(eventName, payload, direction, channel, sentAt, isLeader)

  if direction == "out" then
    Store.AppendOutgoing(state.store, conversationKey, msg)
  else
    local isActive = state.activeConversationKey == conversationKey
    Store.AppendIncoming(state.store, conversationKey, msg, isActive)
  end

  -- Stamp the conversation record with its key, the guild's display name
  -- (so the conversation header can show it even when another character
  -- is logged in), and the last-writing character's profileId (used to
  -- disambiguate "CharName — Guild" for alts not currently in this guild).
  local conversation = state.store.conversations[conversationKey]
  if conversation then
    conversation.conversationKey = conversationKey
    if channel == ChannelType.GUILD and guildName then
      conversation.guildName = guildName
      conversation.ownerProfileId = state.localProfileId
    end
  end

  return true
end

-- Exposed for unit tests that simulate 12.0 "secret string" taint throws.
GroupChatIngest._compareGuids = compareGuids
GroupChatIngest._isSecretString = isSecretString

ns.GroupChatIngest = GroupChatIngest

return GroupChatIngest
