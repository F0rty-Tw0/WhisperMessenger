local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatGateway = ns.ChatGateway or require("WhisperMessenger.Transport.ChatGateway")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

local GroupSendPolicy = {}

local FOREIGN_PROFILE_GROUP_PREFIXES = { "party::", "raid::", "instance::", "officer::" }

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

local function isLegacyWhisperChannel(channel)
  return channel == "WOW" or channel == "BN" or channel == ChannelType.WHISPER or channel == ChannelType.BN_WHISPER
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
      local owner = string.sub(conversationKey, #prefix + 1)
      if owner ~= "" and owner ~= runtime.localProfileId then
        return true
      end
      return false
    end
  end

  return false
end

function GroupSendPolicy.Create(options)
  options = options or {}
  local runtime = options.runtime or {}
  local chatGateway = options.chatGateway or ChatGateway
  local getPlayerGuildName = options.getPlayerGuildName or defaultPlayerGuildName

  local function getNotice(conversation)
    if conversation == nil then
      return nil
    end

    local channel = conversation.channel
    if channel == nil then
      return nil
    end

    -- Legacy whisper channels use "WOW"/"BN"; skip them — they are not group channels.
    if isLegacyWhisperChannel(channel) then
      return nil
    end

    -- COMMUNITY is receive-only but not a group membership issue.
    if channel == ChannelType.COMMUNITY then
      return nil
    end

    -- Foreign-character group history is read-only from this character.
    if isForeignCharacterGroup(runtime, conversation, getPlayerGuildName) then
      return "Another character's history — read-only."
    end

    if not chatGateway.CanSend(runtime.chatApi, conversation) then
      return "Not in group — can't send."
    end

    return nil
  end

  local function shouldRoutePayload(payload)
    local channel = payload and payload.channel
    return channel ~= nil and not isLegacyWhisperChannel(channel)
  end

  local function sendPayload(payload, trace)
    if not chatGateway.CanSend(runtime.chatApi, payload) then
      return false
    end

    local ok, err = pcall(chatGateway.Send, runtime.chatApi, payload, payload.text)
    if not ok and type(trace) == "function" then
      trace("group send error", tostring(err))
    end
    return ok
  end

  return {
    getNotice = getNotice,
    shouldRoutePayload = shouldRoutePayload,
    sendPayload = sendPayload,
    isForeignCharacterGroup = function(conversation)
      return isForeignCharacterGroup(runtime, conversation, getPlayerGuildName)
    end,
  }
end

ns.BootstrapWindowRuntimeGroupSendPolicy = GroupSendPolicy

return GroupSendPolicy
