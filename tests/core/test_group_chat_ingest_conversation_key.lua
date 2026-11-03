local Identity = require("WhisperMessenger.Model.Identity")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")
local ConversationKey = require("WhisperMessenger.Core.Ingest.GroupChatIngest.ConversationKey")

local PROFILE = "arthas-area52"

return function()
  local savedGetGuildInfo = rawget(_G, "GetGuildInfo")
  local savedHome = rawget(_G, "LE_PARTY_CATEGORY_HOME")
  rawset(_G, "LE_PARTY_CATEGORY_HOME", 1)

  -- test_party_uses_session_key_when_party_guid_known

  do
    local state = { localProfileId = PROFILE, groupPartyGUIDsByCategory = { [1] = "Party-1" } }
    local key, category, partyGUID = ConversationKey.Resolve(state, ChannelType.PARTY)
    assert(key == "party::" .. PROFILE .. "::1::Party-1", "unexpected session key " .. tostring(key))
    assert(category == 1, "expected home category 1, got " .. tostring(category))
    assert(partyGUID == "Party-1", "expected party GUID, got " .. tostring(partyGUID))
  end

  -- test_party_falls_back_to_singleton_key_without_party_guid

  do
    local key, category, partyGUID = ConversationKey.Resolve({ localProfileId = PROFILE }, ChannelType.PARTY)
    assert(key == Identity.BuildConversationKey(PROFILE, "PARTY::"), "expected singleton key, got " .. tostring(key))
    assert(category == nil and partyGUID == nil, "singleton key carries no session fields")
  end

  -- test_guild_key_uses_live_guild_name

  do
    rawset(_G, "GetGuildInfo", function()
      return "Knights"
    end)
    local key, _, _, guildName = ConversationKey.Resolve({ localProfileId = PROFILE }, ChannelType.GUILD)
    assert(key == Identity.BuildConversationKey(PROFILE, "GUILD::Knights"), "unexpected guild key " .. tostring(key))
    assert(guildName == "Knights", "expected guild name, got " .. tostring(guildName))
  end

  -- test_non_group_channel_resolves_nil

  do
    assert(ConversationKey.Resolve({ localProfileId = PROFILE }, ChannelType.COMMUNITY) == nil, "community is not a group channel")
  end

  -- test_requires_session_guid_only_for_party_instance_raid

  do
    assert(ConversationKey.RequiresSessionGuid(ChannelType.RAID) == true, "raid needs a session guid")
    assert(ConversationKey.RequiresSessionGuid(ChannelType.GUILD) == false, "guild needs no session guid")
  end

  rawset(_G, "GetGuildInfo", savedGetGuildInfo)
  rawset(_G, "LE_PARTY_CATEGORY_HOME", savedHome)
end
