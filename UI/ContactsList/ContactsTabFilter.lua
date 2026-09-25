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

-- ModeOf names the tab an item belongs to. isRequest is only ever set while
-- the Requests inbox setting is on.
function ContactsTabFilter.ModeOf(item)
  if isGroupChannel(item.channel) then
    return "groups"
  end
  if item.isRequest == true then
    return "requests"
  end
  return "whispers"
end

local function filterMode(items, mode)
  local result = {}
  for _, item in ipairs(items or {}) do
    if ContactsTabFilter.ModeOf(item) == mode then
      result[#result + 1] = item
    end
  end
  return result
end

-- FilterWhispers returns only items that are NOT in a known group channel
-- and not message requests.
-- Nil, "WOW", "BN", "WHISPER", "BN_WHISPER" all pass through as whispers.
function ContactsTabFilter.FilterWhispers(items)
  return filterMode(items, "whispers")
end

function ContactsTabFilter.FilterRequests(items)
  return filterMode(items, "requests")
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
-- mode: "whispers" | "groups" | "requests" | nil (nil defaults to "whispers")
-- showGroupChats: boolean — when false, groups fall back to the whisper filter
function ContactsTabFilter.Apply(items, mode, showGroupChats)
  if mode == "requests" then
    return ContactsTabFilter.FilterRequests(items)
  end
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
