local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local ChatGateway = ns.ChatGateway or require("WhisperMessenger.Transport.ChatGateway")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")
local AddonComm = ns.AddonComm or require("WhisperMessenger.Transport.AddonComm")
local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")
local Localization = ns.Localization or (type(require) == "function" and require("WhisperMessenger.Locale.Localization")) or nil

local GroupSendPolicy = {}

local FOREIGN_PROFILE_GROUP_PREFIXES = { "party::", "raid::", "instance::", "officer::" }

local GROUP_REACTION_ADDON_PREFIX = "WMRX"
local PENDING_MATCH_WINDOW_SECONDS = 15

local function hasConversationKey(conversation)
  return type(conversation) == "table" and type(conversation.conversationKey) == "string" and conversation.conversationKey ~= ""
end

local function isCompetitive(runtime)
  return type(runtime.isCompetitiveContent) == "function" and runtime.isCompetitiveContent()
end

local function isPendingExpired(entry, now)
  return type(now) == "number"
    and type(entry) == "table"
    and type(entry.createdAt) == "number"
    and now - entry.createdAt > PENDING_MATCH_WINDOW_SECONDS
end

local function prunePending(runtime, conversationKey, now)
  local queues = runtime.pendingGroupOutgoing
  local queue = type(queues) == "table" and queues[conversationKey] or nil
  if type(queue) ~= "table" then
    return
  end
  for index = #queue, 1, -1 do
    if isPendingExpired(queue[index], now) then
      table.remove(queue, index)
    end
  end
  if #queue == 0 then
    queues[conversationKey] = nil
  end
end

local function prunePendingQueues(runtime, now)
  local queues = runtime.pendingGroupOutgoing
  if type(queues) ~= "table" then
    return
  end
  for conversationKey in pairs(queues) do
    prunePending(runtime, conversationKey, now)
  end
end

local supportedGroupChannels = {
  PARTY = true,
  RAID = true,
  INSTANCE_CHAT = true,
  GUILD = true,
  OFFICER = true,
}

local function isSupportedGroupChannel(channel)
  return supportedGroupChannels[channel] == true
end

local function createdAt(runtime)
  if type(runtime.now) == "function" then
    local ok, now = pcall(runtime.now)
    if ok and type(now) == "number" then
      return now
    end
  end
  return 0
end

local function recordPending(runtime, conversationKey, entry, now)
  if type(conversationKey) ~= "string" or conversationKey == "" then
    return nil
  end
  prunePendingQueues(runtime, now)
  runtime.pendingGroupOutgoing = runtime.pendingGroupOutgoing or {}
  local queue = runtime.pendingGroupOutgoing[conversationKey]
  if queue == nil then
    queue = {}
    runtime.pendingGroupOutgoing[conversationKey] = queue
  end
  table.insert(queue, entry)
  return entry
end

local function discardPending(runtime, conversationKey, entry)
  local queues = runtime.pendingGroupOutgoing
  local queue = type(queues) == "table" and queues[conversationKey] or nil
  if type(queue) ~= "table" then
    return
  end
  for index, candidate in ipairs(queue) do
    if candidate == entry then
      table.remove(queue, index)
      break
    end
  end
  if #queue == 0 then
    queues[conversationKey] = nil
  end
end

local function defaultPlayerGuildName()
  local getGuildInfo = _G.GetGuildInfo
  if type(getGuildInfo) ~= "function" then
    return nil
  end

  local ok, name = pcall(getGuildInfo, "player")
  if not ok or type(name) ~= "string" or name == "" then
    return nil
  end

  return name
end

local function isWhisperChannel(channel)
  return channel == "WOW" or channel == "BN"
end

local function isForeignCharacterGroup(runtime, conversation, getPlayerGuildName)
  local conversationKey = conversation and conversation.conversationKey
  if type(conversationKey) ~= "string" then
    return false
  end

  -- Guild is account-wide: two alts in the same guild share the
  -- conversation, so "foreign" is decided by whether the current
  -- character is in the conversation's stored guild rather than by
  -- a trailing profileId on the key.
  if string.find(conversationKey, "guild::", 1, true) == 1 then
    local storedGuildName = conversation.guildName
    if type(storedGuildName) == "string" and storedGuildName ~= "" then
      local playerGuildName = getPlayerGuildName()
      if playerGuildName and string.lower(playerGuildName) == string.lower(storedGuildName) then
        return false
      end
      return true
    end

    -- Legacy per-character guild key: fall back to profileId compare.
    local owner = string.sub(conversationKey, 8)
    return owner ~= "" and owner ~= runtime.localProfileId
  end

  for _, prefix in ipairs(FOREIGN_PROFILE_GROUP_PREFIXES) do
    if string.find(conversationKey, prefix, 1, true) == 1 then
      local owner = conversation.ownerProfileId
      if type(owner) ~= "string" or owner == "" then
        owner = string.sub(conversationKey, #prefix + 1)
      end
      return owner ~= "" and owner ~= runtime.localProfileId
    end
  end

  return false
end

function GroupSendPolicy.Create(options)
  options = options or {}
  local runtime = options.runtime or {}
  local chatGateway = options.chatGateway or ChatGateway
  local getPlayerGuildName = options.getPlayerGuildName or defaultPlayerGuildName
  local addonComm = options.addonComm or AddonComm

  local function getNotice(conversation)
    if conversation == nil then
      return nil
    end

    local channel = conversation.channel
    if channel == nil then
      return nil
    end

    -- Whisper records use WOW and BN; all other values are group channels.
    if isWhisperChannel(channel) then
      return nil
    end

    -- COMMUNITY is receive-only but not a group membership issue.
    if channel == ChannelType.COMMUNITY then
      return nil
    end

    -- Foreign-character group history is read-only from this character.
    if isForeignCharacterGroup(runtime, conversation, getPlayerGuildName) then
      return Localization and Localization.Text("Another character's history — read-only.") or "Another character's history — read-only."
    end

    -- A GUID-scoped conversation stays closed after the character joins a
    -- later group of the same channel type.
    if conversation.leftGroup then
      return Localization and Localization.Text("Historical group chat — read-only.") or "Historical group chat — read-only."
    end

    if not chatGateway.CanSend(runtime.chatApi, conversation) then
      return Localization and Localization.Text("Not in group — can't send.") or "Not in group — can't send."
    end

    return nil
  end

  local function shouldRoutePayload(payload)
    local channel = payload and payload.channel
    return channel ~= nil and not isWhisperChannel(channel)
  end

  local function sendNormal(payload, text)
    if not chatGateway.CanSend(runtime.chatApi, payload) then
      return false
    end

    local ok = pcall(chatGateway.Send, runtime.chatApi, payload, text)
    if not ok then
      return false
    end
    return true
  end

  local function sendAddon(payload, encoded)
    if type(addonComm.RegisterPrefix) == "function" then
      addonComm.RegisterPrefix(runtime.chatApi, GROUP_REACTION_ADDON_PREFIX)
    end
    return addonComm.SendGroup(runtime.chatApi, GROUP_REACTION_ADDON_PREFIX, encoded, payload.channel)
  end

  local function sendPayload(payload)
    if type(payload) ~= "table" then
      return false
    end
    if not isSupportedGroupChannel(payload.channel) then
      return sendNormal(payload, payload.text)
    end
    if isCompetitive(runtime) or not hasConversationKey(payload) then
      return false
    end

    local now = createdAt(runtime)
    local wireId = payload.wireId or Protocol.NewWireId(runtime, now)
    payload.wireId = wireId
    local pending = recordPending(runtime, payload.conversationKey, {
      text = payload.text,
      channel = payload.channel,
      createdAt = now,
      wireId = wireId,
    }, now)
    if not sendNormal(payload, payload.text) then
      discardPending(runtime, payload.conversationKey, pending)
      return false
    end

    local identity = Protocol.EncodeIdentity(wireId, payload.text)
    if identity ~= nil then
      sendAddon(payload, identity)
    end
    return true
  end

  local function sendReaction(conversation, message, reactionKey, operation, actorName, pendingToken)
    if type(conversation) ~= "table" or type(message) ~= "table" or not isSupportedGroupChannel(conversation.channel) then
      return false
    end
    if isCompetitive(runtime) or not hasConversationKey(conversation) or getNotice(conversation) ~= nil then
      return false
    end

    local sourceText = message.text or ""
    local fallback = Protocol.BuildGroupFallback(reactionKey, operation, sourceText)
    local targetGuid = message.guid or conversation.guid
    local targetName = message.playerName or conversation.displayName
    local encoded = Protocol.EncodeGroupReaction(operation, reactionKey, message.wireId, sourceText, fallback, targetGuid, targetName)
    local decoded = Protocol.Decode(encoded)
    if fallback == nil or decoded == nil then
      return false
    end

    local reactionControl = {
      actorName = actorName,
      sourceText = sourceText,
      pendingToken = pendingToken,
      operation = decoded,
      targetMessage = message,
      targetConversation = conversation,
    }
    local now = createdAt(runtime)
    local pending = recordPending(runtime, conversation.conversationKey, {
      text = fallback,
      channel = conversation.channel,
      createdAt = now,
      reactionControl = reactionControl,
    }, now)
    if not sendNormal(conversation, fallback) then
      discardPending(runtime, conversation.conversationKey, pending)
      return false
    end
    if not sendAddon(conversation, encoded) then
      discardPending(runtime, conversation.conversationKey, pending)
      return false
    end
    return true, reactionControl
  end

  return {
    getNotice = getNotice,
    shouldRoutePayload = shouldRoutePayload,
    sendPayload = sendPayload,
    sendReaction = sendReaction,
    prunePending = function(conversationKey, now)
      prunePending(runtime, conversationKey, now or createdAt(runtime))
    end,
    isForeignCharacterGroup = function(conversation)
      return isForeignCharacterGroup(runtime, conversation, getPlayerGuildName)
    end,
  }
end

ns.BootstrapWindowRuntimeGroupSendPolicy = GroupSendPolicy

return GroupSendPolicy
