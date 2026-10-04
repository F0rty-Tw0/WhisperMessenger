local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local TimeFormat = ns.TimeFormat or require("WhisperMessenger.Util.TimeFormat")

local GroupLabel = {}

local CHANNEL_LABELS = {
  [ChannelType.PARTY] = "Party",
  [ChannelType.RAID] = "Raid",
  [ChannelType.INSTANCE_CHAT] = "Instance (BG)",
  [ChannelType.BN_CONVERSATION] = "Battle.net Group",
  [ChannelType.GUILD] = "Guild",
  [ChannelType.OFFICER] = "Officer",
  [ChannelType.CHANNEL] = "Channel",
  [ChannelType.COMMUNITY] = "Community",
}

local SESSION_CHANNELS = {
  [ChannelType.PARTY] = true,
  [ChannelType.RAID] = true,
  [ChannelType.INSTANCE_CHAT] = true,
}

-- LabelForChannel returns the display label for a group channel type.
-- Returns "" for whisper channels (WHISPER, BN_WHISPER) and nil.
function GroupLabel.LabelForChannel(channel)
  if channel == nil then
    return ""
  end
  return Localization.Text(CHANNEL_LABELS[channel]) or ""
end

-- LabelForSession adds state only to Party, Raid, and Instance Chat rows.
function GroupLabel.LabelForSession(channel, leftGroup, ownerProfileId, lastActivityAt)
  local label = GroupLabel.LabelForChannel(channel)
  if not SESSION_CHANNELS[channel] then
    return label
  end

  local suffix
  if ownerProfileId == nil and leftGroup ~= true then
    suffix = Localization.Text("Current")
  elseif lastActivityAt and lastActivityAt ~= 0 then
    suffix = TimeFormat.GroupSessionTimestamp(lastActivityAt)
  end

  if type(suffix) ~= "string" or suffix == "" then
    return label
  end
  return label .. " - " .. suffix
end

-- Extract a short display-friendly character name from a profileId like
-- "jaina-proudmoore" → "Jaina". profileIds are lowercased by Identity.normalizeName,
-- so we title-case the first token here for presentation.
function GroupLabel.OwnerShortName(profileId)
  if type(profileId) ~= "string" or profileId == "" then
    return nil
  end
  local token = string.match(profileId, "^[^-]+") or profileId
  if #token == 0 then
    return profileId
  end
  return string.upper(string.sub(token, 1, 1)) .. string.sub(token, 2)
end

-- Resolve the player's current guild name. Returns nil when the player is
-- not in a guild, the API is unavailable (Classic flavors before Wrath),
-- or the call errors.
function GroupLabel.PlayerGuildName()
  local getGuildInfo = _G.GetGuildInfo
  if type(getGuildInfo) ~= "function" then
    return nil
  end
  local ok, name = pcall(getGuildInfo, "player")
  if not ok then
    return nil
  end
  if type(name) == "string" and name ~= "" then
    return name
  end
  return nil
end

-- LabelForChannelAndTitle returns the display label for a channel, using
-- conversation.title when available for channels whose identity is not a
-- singleton (BN_CONVERSATION with its conversationID, COMMUNITY with its
-- stream name). CHANNEL chats are named by displayName, the channel's base
-- name ("Trade") that ingest stamps on every line. For other channels the
-- title is ignored. Guild stays as the canonical "Guild" here so the
-- contact row keeps a compact label; the conversation header resolves the
-- live guild name separately.
function GroupLabel.LabelForChannelAndTitle(channel, title, displayName)
  if channel == ChannelType.CHANNEL and type(displayName) == "string" and displayName ~= "" then
    return displayName
  end
  if channel == ChannelType.BN_CONVERSATION then
    if type(title) == "string" and title ~= "" then
      return title
    end
    return Localization.Text("Battle.net Group")
  end
  if channel == ChannelType.COMMUNITY then
    if type(title) == "string" and title ~= "" then
      return title
    end
    return "Community"
  end
  return GroupLabel.LabelForChannel(channel)
end

-- Only explicitly-known Stage-4 group-ingest channel values get group-row
-- styling. Legacy values ("WOW", "BN", nil) render as normal whisper rows.
-- IsGroupItem returns true when the item represents a known group conversation.
function GroupLabel.IsGroupItem(item)
  return item ~= nil and ChannelType.GROUP_CHANNELS[item.channel] == true
end

-- ForItem returns the contact-row label for a group item: "Party",
-- "Instance (BG)", a community's name, etc. rather than the internal key.
-- Group chats carried over from another character get an owner prefix
-- ("Jaina - Guild") so the player can tell which alt's history this is.
function GroupLabel.ForItem(item)
  local groupName
  if item.channel == ChannelType.PARTY or item.channel == ChannelType.RAID or item.channel == ChannelType.INSTANCE_CHAT then
    groupName = GroupLabel.LabelForSession(item.channel, item.leftGroup, item.ownerProfileId, item.lastActivityAt)
  else
    groupName = GroupLabel.LabelForChannelAndTitle(item.channel, item.title, item.displayName)
  end
  if groupName == "" then
    groupName = item.displayName or ""
  end
  local ownerName = GroupLabel.OwnerShortName(item.ownerProfileId)
  if ownerName then
    groupName = ownerName .. " - " .. groupName
  end
  return groupName
end

ns.ContactsListGroupLabel = GroupLabel
return GroupLabel
