local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")

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

-- LabelForChannel returns the display label for a group channel type.
-- Returns "" for whisper channels (WHISPER, BN_WHISPER) and nil.
function GroupLabel.LabelForChannel(channel)
  if channel == nil then
    return ""
  end
  return CHANNEL_LABELS[channel] or ""
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
-- stream name). For other channels the title is ignored. Guild stays as
-- the canonical "Guild" here so the contact row keeps a compact label;
-- the conversation header resolves the live guild name separately.
function GroupLabel.LabelForChannelAndTitle(channel, title)
  if channel == ChannelType.BN_CONVERSATION then
    if type(title) == "string" and title ~= "" then
      return title
    end
    return "Battle.net Group"
  end
  if channel == ChannelType.COMMUNITY then
    if type(title) == "string" and title ~= "" then
      return title
    end
    return "Community"
  end
  return GroupLabel.LabelForChannel(channel)
end

ns.ContactsListGroupLabel = GroupLabel
return GroupLabel
