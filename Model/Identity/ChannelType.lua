local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelType = {}

-- Constants (string values for SavedVariables/JSON friendliness)
ChannelType.WHISPER = "WHISPER"
ChannelType.BN_WHISPER = "BN_WHISPER"
ChannelType.BN_CONVERSATION = "BN_CONVERSATION"
ChannelType.PARTY = "PARTY"
ChannelType.RAID = "RAID"
ChannelType.INSTANCE_CHAT = "INSTANCE_CHAT"
ChannelType.GUILD = "GUILD"
ChannelType.OFFICER = "OFFICER"
ChannelType.CHANNEL = "CHANNEL"
ChannelType.COMMUNITY = "COMMUNITY"

-- Group chats: every channel except one-to-one whispers.
ChannelType.GROUP_CHANNELS = {
  [ChannelType.BN_CONVERSATION] = true,
  [ChannelType.PARTY] = true,
  [ChannelType.RAID] = true,
  [ChannelType.INSTANCE_CHAT] = true,
  [ChannelType.GUILD] = true,
  [ChannelType.OFFICER] = true,
  [ChannelType.CHANNEL] = true,
  [ChannelType.COMMUNITY] = true,
}

-- Subset of GROUP_CHANNELS that SendAddonMessage can broadcast to; group
-- reactions travel only on these.
ChannelType.ADDON_GROUP_CHANNELS = {
  [ChannelType.PARTY] = true,
  [ChannelType.RAID] = true,
  [ChannelType.INSTANCE_CHAT] = true,
  [ChannelType.GUILD] = true,
  [ChannelType.OFFICER] = true,
}

ns.ChannelType = ChannelType

return ChannelType
