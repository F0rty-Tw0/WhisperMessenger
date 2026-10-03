local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local Store = ns.ConversationStore or require("WhisperMessenger.Model.ConversationStore")
local LocalPlayer = ns.LocalPlayer or require("WhisperMessenger.Core.LocalPlayer")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local DuplicateCollapse = ns.DuplicateCollapse or require("WhisperMessenger.Model.Filters.DuplicateCollapse")
local IncomingFilter = ns.IncomingFilter or require("WhisperMessenger.Core.Ingest.IncomingFilter")
local PerfCounters = ns.PerfCounters or require("WhisperMessenger.Util.PerfCounters")
local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
-- stylua: ignore start
local SecretString = ns.GroupChatIngestSecretString or require("WhisperMessenger.Core.Ingest.GroupChatIngest.SecretString")
local Direction = ns.GroupChatIngestDirection or require("WhisperMessenger.Core.Ingest.GroupChatIngest.Direction")
local Mention = ns.GroupChatIngestMention or require("WhisperMessenger.Core.Ingest.GroupChatIngest.Mention")
local ChannelKey = ns.ChannelChatIngestChannelKey or require("WhisperMessenger.Core.Ingest.ChannelChatIngest.ChannelKey")
-- stylua: ignore end

-- Public channel lines (Trade, General, custom channels) become one CHANNEL
-- conversation per channel, for the channels the player turned on. No
-- addon-protocol or reaction work: public channels carry neither.
local ChannelChatIngest = {}

local CHANNEL = "CHANNEL"
local EVENT_NAME = "CHAT_MSG_CHANNEL"

-- Tells the router a mention arrived so it can alert. Read-only, shared.
local MENTION_META = { mention = true }

-- Shared and read-only, so a line without player info allocates nothing.
local NO_PLAYER_INFO = {}

local function buildMessage(payload, direction, sentAt, playerInfo)
  playerInfo = playerInfo or NO_PLAYER_INFO
  local message = {
    id = tostring(payload.lineID or sentAt),
    direction = direction,
    kind = "user",
    text = payload.text,
    sentAt = sentAt,
    lineID = payload.lineID,
    guid = payload.guid,
    playerName = payload.playerName,
    channel = CHANNEL,
    -- Class icon and colour for the bubble, as on group lines.
    className = playerInfo.className,
    classTag = playerInfo.classTag,
    raceName = playerInfo.raceName,
    raceTag = playerInfo.raceTag,
  }
  if direction == "out" then
    -- Same frozen sender fields as the player's own group lines.
    message.senderClassTag = playerInfo.classTag or LocalPlayer.ClassTag()
    message.senderName = LocalPlayer.Name()
  elseif Mention.Matches(payload.text, Mention.PlayerName()) then
    message.mention = true
  end
  return message
end

-- A row before the line when the zone part of the channel name changed.
local function appendZoneDivider(state, key, conversation, zoneLabel, sentAt)
  if conversation == nil or conversation.lastZoneLabel == nil or zoneLabel == nil or conversation.lastZoneLabel == zoneLabel then
    return
  end
  Store.AppendIncoming(state.store, key, {
    id = tostring(sentAt) .. "-zone",
    kind = "system",
    direction = "in",
    text = string.format(Localization.Text("Zone: %s"), zoneLabel),
    sentAt = sentAt,
    channel = CHANNEL,
  }, true)
end

-- The repeated row when this sender already said this line, else nil.
local function findRepeat(state, conversation, payload)
  local settings = state.accountState and state.accountState.settings
  if state.collapseIndex == nil or (settings and settings.collapseDuplicates == false) then
    return nil
  end
  local senderKey = DuplicateCollapse.SenderKey(payload.playerName)
  if senderKey == nil then
    return nil
  end
  local normalized = DuplicateCollapse.NormalizeText(payload.text)
  return DuplicateCollapse.Find(state.collapseIndex, conversation, senderKey, normalized), senderKey, normalized
end

local function isEnabled(state, slug)
  local settings = state.accountState and state.accountState.settings
  local enabled = settings and settings.enabledChannels
  return type(enabled) == "table" and enabled[ChannelKey.SettingKey(slug)] == true
end

local function stamp(conversation, key, payload, state, zoneLabel)
  conversation.conversationKey = key
  conversation.channel = CHANNEL
  conversation.displayName = ChannelKey.BaseName(payload.channelBaseName) or conversation.displayName
  conversation.channelIndex = payload.channelIndex or conversation.channelIndex
  conversation.channelBaseName = payload.channelBaseName or conversation.channelBaseName
  conversation.ownerProfileId = state.localProfileId
  conversation.lastZoneLabel = zoneLabel or conversation.lastZoneLabel
end

-- payload: { text, playerName, channelName, zoneChannelID, channelIndex,
-- channelBaseName, lineID, guid }. Returns handled, conversation, meta.
function ChannelChatIngest.HandleEvent(state, payload)
  if type(state) ~= "table" or type(payload) ~= "table" then
    return false
  end
  if SecretString.PayloadHasSecretFields(payload, ChannelChatIngest._isSecretString) then
    return false
  end
  local slug = ChannelKey.Slug(payload.zoneChannelID, payload.channelBaseName)
  if slug == nil or not isEnabled(state, slug) then
    return false
  end

  local isSelf = Direction.IsLocalSender(EVENT_NAME, payload.guid, nil, state)
  local label = ChannelKey.BaseName(payload.channelBaseName)
  if IncomingFilter.Evaluate(state, "channel", payload.playerName, payload.text, payload.lineID, label, isSelf) ~= "pass" then
    return true, nil
  end

  local key = Identity.BuildConversationKey(state.localProfileId, "CHANNEL::" .. slug)
  local sentAt = (state.now and state.now()) or 0
  local conversation = state.store.conversations[key]
  PerfCounters.Increment("channelLines")

  local repeated, senderKey, normalized
  if not isSelf then
    repeated, senderKey, normalized = findRepeat(state, conversation, payload)
  end
  if repeated ~= nil then
    -- An in-place repeat adds no row, so the zone divider waits for the
    -- next new line.
    Store.CollapseRepeat(state.store, key, repeated, sentAt)
    PerfCounters.Increment("collapsed")
    return true, conversation
  end

  local zoneLabel = ChannelKey.ZoneLabel(payload.channelName)
  appendZoneDivider(state, key, conversation, zoneLabel, sentAt)
  local playerInfo = BNetResolver.ResolvePlayerInfo(state.playerInfoByGUID, payload.guid)
  local message = buildMessage(payload, isSelf and "out" or "in", sentAt, playerInfo)
  if isSelf then
    Store.AppendOutgoing(state.store, key, message)
  else
    -- Only a line naming the player counts as unread: busy Trade must not
    -- bury real unread chats. AppendIncoming skips unread for "active".
    local skipUnread = state.activeConversationKey == key or not message.mention
    Store.AppendIncoming(state.store, key, message, skipUnread)
  end
  conversation = state.store.conversations[key]
  if conversation == nil then
    return true, nil
  end
  stamp(conversation, key, payload, state, zoneLabel)
  if senderKey ~= nil then
    DuplicateCollapse.Remember(state.collapseIndex, key, senderKey, normalized, message)
  end
  return true, conversation, message.mention and MENTION_META or nil
end

-- Exposed so tests can simulate 12.0 secret strings.
ChannelChatIngest._isSecretString = SecretString.IsSecretString

ns.ChannelChatIngest = ChannelChatIngest
return ChannelChatIngest
