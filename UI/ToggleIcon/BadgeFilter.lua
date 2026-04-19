local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

local BadgeFilter = {}

-- Only the explicitly-known Stage-4 group-ingest channel values are treated as
-- group channels for badge-exclusion purposes. Legacy channel strings such as
-- "WOW" and "BN" (written by the pre-Stage-1 whisper pipeline) are treated as
-- whispers so they continue to count toward the badge.
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

-- IsGroupChannel returns true only for explicitly-known group channels.
-- Nil, "WOW", "BN", WHISPER, BN_WHISPER all return false so whisper-only
-- surfaces (minimap badge, widget preview popup) continue to work.
function BadgeFilter.IsGroupChannel(channel)
  return isGroupChannel(channel)
end

-- SumWhisperUnread returns the aggregate unread count across all contacts
-- that are NOT group conversations. Group conversations are intentionally
-- excluded from the minimap/widget badge per user requirement.
-- Nil, unknown, or legacy channel values ("WOW", "BN") are treated as
-- whispers and DO count toward the badge total.
function BadgeFilter.SumWhisperUnread(contacts)
  local total = 0
  for _, contact in ipairs(contacts or {}) do
    if not isGroupChannel(contact.channel) then
      total = total + (tonumber(contact.unreadCount) or 0)
    end
  end
  return total
end

-- SumGroupUnread returns the aggregate unread count across all group
-- conversations only. Used for the Groups tab label counter.
function BadgeFilter.SumGroupUnread(contacts)
  local total = 0
  for _, contact in ipairs(contacts or {}) do
    if isGroupChannel(contact.channel) then
      total = total + (tonumber(contact.unreadCount) or 0)
    end
  end
  return total
end

ns.ToggleIconBadgeFilter = BadgeFilter
return BadgeFilter
