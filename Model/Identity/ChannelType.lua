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

local knownValues = {
  [ChannelType.WHISPER] = true,
  [ChannelType.BN_WHISPER] = true,
  [ChannelType.BN_CONVERSATION] = true,
  [ChannelType.PARTY] = true,
  [ChannelType.RAID] = true,
  [ChannelType.INSTANCE_CHAT] = true,
  [ChannelType.GUILD] = true,
  [ChannelType.OFFICER] = true,
  [ChannelType.CHANNEL] = true,
  [ChannelType.COMMUNITY] = true,
}

-- IsKnown returns true iff value is one of the 10 defined constants.
function ChannelType.IsKnown(value)
  return knownValues[value] == true
end

-- IsGroup returns true for all channels except WHISPER and BN_WHISPER.
function ChannelType.IsGroup(value)
  return value ~= ChannelType.WHISPER and value ~= ChannelType.BN_WHISPER
end

-- IsPersistent returns true for channels whose history survives leaving the group.
-- Ephemeral channels (PARTY, RAID, INSTANCE_CHAT) return false.
function ChannelType.IsPersistent(value)
  return value == ChannelType.WHISPER
    or value == ChannelType.BN_WHISPER
    or value == ChannelType.BN_CONVERSATION
    or value == ChannelType.GUILD
    or value == ChannelType.OFFICER
    or value == ChannelType.CHANNEL
    or value == ChannelType.COMMUNITY
end

-- IsSendable returns true for all channels except COMMUNITY.
-- C_Club.SendMessage has been Blizzard-protected for addons since patch 8.1.0.
function ChannelType.IsSendable(value)
  return value ~= ChannelType.COMMUNITY
end

ns.ChannelType = ChannelType

return ChannelType
