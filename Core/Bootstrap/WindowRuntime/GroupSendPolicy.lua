local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local ChatGateway = ns.ChatGateway or require("WhisperMessenger.Transport.ChatGateway")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")
local AddonComm = ns.AddonComm or require("WhisperMessenger.Transport.AddonComm")
local Protocol = ns.MessageReactionProtocol or require("WhisperMessenger.Model.MessageReactionProtocol")
local Localization = ns.Localization or (type(require) == "function" and require("WhisperMessenger.Locale.Localization")) or nil
local Pending = ns.BootstrapWindowRuntimeGroupSendPending or require("WhisperMessenger.Core.Bootstrap.WindowRuntime.GroupSendPending")

local GroupSendPolicy = {}

local FOREIGN_PROFILE_GROUP_PREFIXES = { "party::", "raid::", "instance::", "officer::", "channel::" }

local function hasConversationKey(conversation)
  return type(conversation) == "table" and type(conversation.conversationKey) == "string" and conversation.conversationKey ~= ""
end

local function isCompetitive(runtime)
  return type(runtime.isCompetitiveContent) == "function" and runtime.isCompetitiveContent()
end

local function isSupportedGroupChannel(channel)
  return ChannelType.ADDON_GROUP_CHANNELS[channel] == true
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

    -- COMMUNITY is receive-only: replies go through the Communities window.
    if channel == ChannelType.COMMUNITY then
      return Localization and Localization.Text("Read-only here. Reply in the game's Communities window.")
        or "Read-only here. Reply in the game's Communities window."
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
      local key = channel == ChannelType.CHANNEL and "Not in this channel — can't send." or "Not in group — can't send."
      return Localization and Localization.Text(key) or key
    end

    return nil
  end

  local function shouldRoutePayload(payload)
    local channel = payload and payload.channel
    return channel ~= nil and not isWhisperChannel(channel)
  end

  local function sendNormal(payload, text)
    -- The composer payload names only the chat; a channel send needs the
    -- stored channel name to find its live number.
    if payload.channel == ChannelType.CHANNEL and runtime.store and runtime.store.conversations[payload.conversationKey] then
      payload = runtime.store.conversations[payload.conversationKey]
    end
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
      addonComm.RegisterPrefix(runtime.chatApi, AddonComm.PREFIX_REACTION)
    end
    return addonComm.SendGroup(runtime.chatApi, AddonComm.PREFIX_REACTION, encoded, payload.channel)
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

    local now = Pending.Now(runtime)
    local wireId = payload.wireId or Protocol.NewWireId(runtime, now)
    payload.wireId = wireId
    local pending = Pending.Record(runtime, payload.conversationKey, {
      text = payload.text,
      channel = payload.channel,
      createdAt = now,
      wireId = wireId,
    }, now)
    if not sendNormal(payload, payload.text) then
      Pending.Discard(runtime, payload.conversationKey, pending)
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
    local hintSuffix
    if conversation.addonHintSent ~= true then
      hintSuffix = Protocol.ADDON_HINT_SUFFIX
    end
    local fallback = Protocol.BuildGroupFallback(reactionKey, operation, sourceText, hintSuffix)
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
    local now = Pending.Now(runtime)
    local pending = Pending.Record(runtime, conversation.conversationKey, {
      text = fallback,
      channel = conversation.channel,
      createdAt = now,
      reactionControl = reactionControl,
    }, now)
    if not sendNormal(conversation, fallback) then
      Pending.Discard(runtime, conversation.conversationKey, pending)
      return false
    end
    if not sendAddon(conversation, encoded) then
      Pending.Discard(runtime, conversation.conversationKey, pending)
      return false
    end
    if hintSuffix ~= nil then
      conversation.addonHintSent = true
    end
    return true, reactionControl
  end

  return {
    getNotice = getNotice,
    shouldRoutePayload = shouldRoutePayload,
    sendPayload = sendPayload,
    sendReaction = sendReaction,
    prunePending = function(conversationKey, now)
      Pending.Prune(runtime, conversationKey, now or Pending.Now(runtime))
    end,
    isForeignCharacterGroup = function(conversation)
      return isForeignCharacterGroup(runtime, conversation, getPlayerGuildName)
    end,
  }
end

ns.BootstrapWindowRuntimeGroupSendPolicy = GroupSendPolicy

return GroupSendPolicy
