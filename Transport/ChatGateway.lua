local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local WhisperGateway = ns.WhisperGateway or require("WhisperMessenger.Transport.WhisperGateway")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

local Gateway = {}

-- ---------------------------------------------------------------------------
-- Sender resolvers
-- ---------------------------------------------------------------------------

-- Resolve a C_ChatInfo.SendChatMessage-compatible function.
-- Prefers injected api.SendChatMessage; falls back to _G.C_ChatInfo.SendChatMessage.
-- Returns nil if neither is available.
local function resolveChatSender(api)
  if type(api) == "table" and type(api.SendChatMessage) == "function" then
    return api.SendChatMessage
  end
  if type(_G.C_ChatInfo) == "table" and type(_G.C_ChatInfo.SendChatMessage) == "function" then
    return _G.C_ChatInfo.SendChatMessage
  end
  return nil
end

-- Resolve BNSendConversationMessage.
-- Prefers injected api.SendConversationMessage; falls back to _G.BNSendConversationMessage.
-- Returns nil if neither is available.
local function resolveConversationSender(api)
  if type(api) == "table" and type(api.SendConversationMessage) == "function" then
    return api.SendConversationMessage
  end
  if type(_G.BNSendConversationMessage) == "function" then
    return _G.BNSendConversationMessage
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- Per-channel send functions
-- ---------------------------------------------------------------------------

-- Delegates to WhisperGateway.SendCharacterWhisper.
function Gateway.SendWhisper(api, target, text)
  return WhisperGateway.SendCharacterWhisper(api, target, text)
end

-- Delegates to WhisperGateway.SendBattleNetWhisper.
function Gateway.SendBattleNetWhisper(api, bnetAccountID, text)
  return WhisperGateway.SendBattleNetWhisper(api, bnetAccountID, text)
end

-- Sends a BNet conversation message.
function Gateway.SendBattleNetConversation(api, conversationID, text)
  local sender = resolveConversationSender(api)
  if sender == nil then
    error("No Battle.net conversation sender available")
  end
  return sender(conversationID, text)
end

-- Sends to PARTY chat.
function Gateway.SendParty(api, text)
  local sender = resolveChatSender(api)
  if sender == nil then
    error("No chat sender available")
  end
  return sender(text, "PARTY")
end

-- Sends to RAID or RAID_WARNING chat.
-- Pass warning=true to use RAID_WARNING.
function Gateway.SendRaid(api, text, warning)
  local sender = resolveChatSender(api)
  if sender == nil then
    error("No chat sender available")
  end
  local chatType = warning and "RAID_WARNING" or "RAID"
  return sender(text, chatType)
end

-- Sends to INSTANCE_CHAT.
function Gateway.SendInstance(api, text)
  local sender = resolveChatSender(api)
  if sender == nil then
    error("No chat sender available")
  end
  return sender(text, "INSTANCE_CHAT")
end

-- Sends to GUILD chat.
function Gateway.SendGuild(api, text)
  local sender = resolveChatSender(api)
  if sender == nil then
    error("No chat sender available")
  end
  return sender(text, "GUILD")
end

-- Sends to OFFICER chat.
function Gateway.SendOfficer(api, text)
  local sender = resolveChatSender(api)
  if sender == nil then
    error("No chat sender available")
  end
  return sender(text, "OFFICER")
end

-- Sends to a numbered chat CHANNEL.
-- Caller is responsible for resolving channelIndex from a stable name at send time.
function Gateway.SendChannel(api, channelIndex, text)
  local sender = resolveChatSender(api)
  if sender == nil then
    error("No chat sender available")
  end
  return sender(text, "CHANNEL", nil, channelIndex)
end

-- ---------------------------------------------------------------------------
-- Dispatcher
-- ---------------------------------------------------------------------------

-- checkMembership(fn, ...) calls fn(...) inside pcall and returns the boolean
-- result. Returns false if fn errors or returns a non-true value.
local function checkMembership(fn, ...)
  local ok, result = pcall(fn, ...)
  return ok and result == true
end

-- Map from ChannelType constant to a resolver function.
-- COMMUNITY is intentionally absent — it is receive-only.
local senderAvailability = {
  [ChannelType.WHISPER] = function(api)
    return WhisperGateway.CanSendCharacterWhisper(api)
  end,
  [ChannelType.BN_WHISPER] = function(api)
    return WhisperGateway.CanSendBattleNetWhisper(api)
  end,
  [ChannelType.BN_CONVERSATION] = function(api, conversation)
    if resolveConversationSender(api) == nil then
      return false
    end
    -- If BNGetConversationInfo is available, verify the conversation exists.
    if type(_G.BNGetConversationInfo) == "function" then
      local conversationID = type(conversation) == "table" and conversation.conversationID or nil
      local ok, info = pcall(_G.BNGetConversationInfo, conversationID)
      return ok and info ~= nil
    end
    return true
  end,
  [ChannelType.PARTY] = function(api)
    if resolveChatSender(api) == nil then
      return false
    end
    if type(_G.IsInGroup) == "function" then
      local category = type(_G.LE_PARTY_CATEGORY_HOME) == "number" and _G.LE_PARTY_CATEGORY_HOME or 1
      return checkMembership(_G.IsInGroup, category)
    end
    return true
  end,
  [ChannelType.RAID] = function(api)
    if resolveChatSender(api) == nil then
      return false
    end
    if type(_G.IsInRaid) == "function" then
      return checkMembership(_G.IsInRaid)
    end
    return true
  end,
  [ChannelType.INSTANCE_CHAT] = function(api)
    if resolveChatSender(api) == nil then
      return false
    end
    if type(_G.IsInGroup) == "function" then
      local category = type(_G.LE_PARTY_CATEGORY_INSTANCE) == "number" and _G.LE_PARTY_CATEGORY_INSTANCE or 2
      return checkMembership(_G.IsInGroup, category)
    end
    return true
  end,
  [ChannelType.GUILD] = function(api)
    if resolveChatSender(api) == nil then
      return false
    end
    if type(_G.IsInGuild) == "function" then
      return checkMembership(_G.IsInGuild)
    end
    return true
  end,
  [ChannelType.OFFICER] = function(api)
    if resolveChatSender(api) == nil then
      return false
    end
    if type(_G.IsInGuild) == "function" then
      return checkMembership(_G.IsInGuild)
    end
    return true
  end,
  [ChannelType.CHANNEL] = function(api, conversation)
    if resolveChatSender(api) == nil then
      return false
    end
    if type(_G.GetChannelName) == "function" then
      local baseName = type(conversation) == "table" and conversation.channelBaseName or nil
      local ok, index = pcall(_G.GetChannelName, baseName)
      return ok and type(index) == "number" and index ~= 0
    end
    return true
  end,
}

-- CanSend returns true iff a send call for this conversation would succeed.
-- Never throws.
function Gateway.CanSend(api, conversation)
  if type(conversation) ~= "table" then
    return false
  end
  local channel = conversation.channel
  if channel == ChannelType.COMMUNITY then
    return false
  end
  local checker = senderAvailability[channel]
  if checker == nil then
    return false
  end
  local ok, result = pcall(checker, api, conversation)
  return ok and result == true
end

-- Send dispatches to the correct per-channel sender based on conversation.channel.
-- Throws when the channel is COMMUNITY (receive-only) or unknown.
function Gateway.Send(api, conversation, text)
  local channel = conversation and conversation.channel

  if channel == ChannelType.WHISPER then
    return Gateway.SendWhisper(api, conversation.target, text)
  elseif channel == ChannelType.BN_WHISPER then
    return Gateway.SendBattleNetWhisper(api, conversation.bnetAccountID, text)
  elseif channel == ChannelType.BN_CONVERSATION then
    return Gateway.SendBattleNetConversation(api, conversation.conversationID, text)
  elseif channel == ChannelType.PARTY then
    return Gateway.SendParty(api, text)
  elseif channel == ChannelType.RAID then
    return Gateway.SendRaid(api, text, false)
  elseif channel == ChannelType.INSTANCE_CHAT then
    return Gateway.SendInstance(api, text)
  elseif channel == ChannelType.GUILD then
    return Gateway.SendGuild(api, text)
  elseif channel == ChannelType.OFFICER then
    return Gateway.SendOfficer(api, text)
  elseif channel == ChannelType.CHANNEL then
    return Gateway.SendChannel(api, conversation.channelIndex, text)
  elseif channel == ChannelType.COMMUNITY then
    error("COMMUNITY is receive-only: addon sends are blocked by Blizzard C_Club protection")
  else
    error("Unknown channel: " .. tostring(channel))
  end
end

ns.ChatGateway = Gateway

return Gateway
