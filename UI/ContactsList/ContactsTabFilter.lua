local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

local ContactsTabFilter = {}

-- Only explicitly-known Stage-4 group-ingest channel values are treated as
-- group channels for filter purposes. Legacy values ("WOW", "BN", nil) are
-- treated as whispers so the existing whisper pipeline is unaffected.
local KNOWN_GROUP_CHANNELS = {
  [ChannelType.BN_CONVERSATION] = true,
  [ChannelType.PARTY] = true,
  [ChannelType.RAID] = true,
  [ChannelType.INSTANCE_CHAT] = true,
  [ChannelType.GUILD] = true,
  [ChannelType.OFFICER] = true,
  [ChannelType.CHANNEL] = true,
  [ChannelType.COMMUNITY] = true,
}

local function isGroupChannel(channel)
  return KNOWN_GROUP_CHANNELS[channel] == true
end

-- IsGroupChannel exposes the predicate for callers that need to classify a
-- conversation by channel without running a full filter pass.
ContactsTabFilter.IsGroupChannel = isGroupChannel

-- FilterWhispers returns only items that are NOT in a known group channel.
-- Nil, "WOW", "BN", "WHISPER", "BN_WHISPER" all pass through as whispers.
function ContactsTabFilter.FilterWhispers(items)
  local result = {}
  for _, item in ipairs(items or {}) do
    if not isGroupChannel(item.channel) then
      result[#result + 1] = item
    end
  end
  return result
end

-- FilterGroups returns only items that ARE in a known group channel.
function ContactsTabFilter.FilterGroups(items)
  local result = {}
  for _, item in ipairs(items or {}) do
    if isGroupChannel(item.channel) then
      result[#result + 1] = item
    end
  end
  return result
end

-- Apply filters the item list according to mode and feature flag.
-- mode: "whispers" | "groups" | nil (nil defaults to "whispers")
-- showGroupChats: boolean — when false, always returns whisper filter
function ContactsTabFilter.Apply(items, mode, showGroupChats)
  if not showGroupChats then
    return ContactsTabFilter.FilterWhispers(items)
  end
  if mode == "groups" then
    return ContactsTabFilter.FilterGroups(items)
  end
  return ContactsTabFilter.FilterWhispers(items)
end

ns.ContactsTabFilter = ContactsTabFilter
return ContactsTabFilter
