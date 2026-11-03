local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

-- Resolves the conversation key a group channel line is stored under:
-- per-session for party/instance/raid when the party GUID is known,
-- account-wide per guild for GUILD, singleton otherwise.
local ConversationKey = {}

-- Contact key prefix per channel type (for singleton group channels)
local CHANNEL_CONTACT_KEY = {
  [ChannelType.PARTY] = "PARTY::",
  [ChannelType.INSTANCE_CHAT] = "INSTANCE::",
  [ChannelType.RAID] = "RAID::",
  [ChannelType.GUILD] = "GUILD::",
  [ChannelType.OFFICER] = "OFFICER::",
}

local GROUP_CONVERSATION_KEY_PREFIX = {
  [ChannelType.PARTY] = "party::",
  [ChannelType.INSTANCE_CHAT] = "instance::",
  [ChannelType.RAID] = "raid::",
}

function ConversationKey.RequiresSessionGuid(channel)
  return GROUP_CONVERSATION_KEY_PREFIX[channel] ~= nil
end

local function groupCategoryForChannel(channel)
  if channel == ChannelType.PARTY or channel == ChannelType.RAID then
    return type(_G.LE_PARTY_CATEGORY_HOME) == "number" and _G.LE_PARTY_CATEGORY_HOME or 1
  end
  if channel == ChannelType.INSTANCE_CHAT then
    return type(_G.LE_PARTY_CATEGORY_INSTANCE) == "number" and _G.LE_PARTY_CATEGORY_INSTANCE or 2
  end
  return nil
end

local function buildGroupSessionKey(state, channel)
  local prefix = GROUP_CONVERSATION_KEY_PREFIX[channel]
  local category = groupCategoryForChannel(channel)
  local partyGUIDs = state.groupPartyGUIDsByCategory
  local partyGUID = partyGUIDs and partyGUIDs[category]
  if prefix == nil or type(state.localProfileId) ~= "string" or state.localProfileId == "" or type(partyGUID) ~= "string" or partyGUID == "" then
    return nil
  end

  return prefix .. state.localProfileId .. "::" .. category .. "::" .. partyGUID, category, partyGUID
end

-- Returns conversationKey, groupCategory, partyGUID, guildName; nil for
-- channels outside ChannelType.ADDON_GROUP_CHANNELS.
function ConversationKey.Resolve(state, channel)
  if not ChannelType.ADDON_GROUP_CHANNELS[channel] then
    return nil
  end
  local contactKeyPrefix = CHANNEL_CONTACT_KEY[channel]
  local guildName
  if channel == ChannelType.GUILD and type(_G.GetGuildInfo) == "function" then
    local ok, name = pcall(_G.GetGuildInfo, "player")
    if ok and type(name) == "string" and name ~= "" then
      guildName = name
      contactKeyPrefix = "GUILD::" .. name
    end
  end
  local conversationKey, groupCategory, partyGUID = buildGroupSessionKey(state, channel)
  if conversationKey == nil then
    conversationKey = Identity.BuildConversationKey(state.localProfileId, contactKeyPrefix)
  end
  return conversationKey, groupCategory, partyGUID, guildName
end

ns.GroupChatIngestConversationKey = ConversationKey
return ConversationKey
