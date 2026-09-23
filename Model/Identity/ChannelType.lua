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

ns.ChannelType = ChannelType

return ChannelType
