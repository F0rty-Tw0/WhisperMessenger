local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChannelType = ns.ChannelType or require("WhisperMessenger.Model.Identity.ChannelType")
local GroupLabel = ns.ContactsListGroupLabel or require("WhisperMessenger.UI.ContactsList.GroupLabel")

local GroupHeaderViewModel = {}

-- Only explicitly-known Stage-4 group-ingest channel values trigger the
-- group-header layout. Legacy values ("WOW", "BN", nil) render as whispers.
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

-- Build constructs a view-model table describing how the ConversationPane
-- header should render for the given contact and conversation.
--
-- Returns nil when contact is nil.
-- Fields:
--   isGroup         boolean   — true when the channel is a known group channel
--   title           string    — text to display in the header name area
--   showPresenceDot boolean   — show online/offline status dot
--   showFactionIcon boolean   — show Alliance/Horde faction icon
--   showStatusLine  boolean   — show zone/last-seen status text
--   channelChip     string|nil — short label chip shown near title for groups
function GroupHeaderViewModel.Build(contact, conversation)
  if contact == nil then
    return nil
  end

  local channel = contact.channel
  local isGroup = isGroupChannel(channel)

  if not isGroup then
    return {
      isGroup = false,
      title = contact.displayName or "",
      showPresenceDot = true,
      showFactionIcon = true,
      showStatusLine = true,
      channelChip = nil,
    }
  end

  -- Group channel: derive label, hide presence/faction/status
  local convTitle = conversation and conversation.title or nil
  local label = GroupLabel.LabelForChannelAndTitle(channel, convTitle)
  local fromAnotherCharacter = contact.ownerProfileId ~= nil and contact.ownerProfileId ~= ""
  -- GUILD: the conversation header shows the guild's name. Prefer the
  -- name stored on the conversation (always correct for account-wide
  -- guild keys, including ones that don't belong to the current login);
  -- fall back to the live PlayerGuildName when the conversation doesn't
  -- carry one yet (legacy per-character key or not-yet-ingested).
  if channel == ChannelType.GUILD then
    local storedGuildName = contact.guildName or (conversation and conversation.guildName) or nil
    if storedGuildName and storedGuildName ~= "" then
      label = storedGuildName
    elseif not fromAnotherCharacter then
      local guildName = GroupLabel.PlayerGuildName and GroupLabel.PlayerGuildName() or nil
      if guildName then
        label = guildName
      end
    end
  end
  -- When the conversation is carried over from another character, prefix
  -- the header title with that character's short name so the user knows
  -- which alt's history they're looking at.
  if fromAnotherCharacter then
    local ownerName = GroupLabel.OwnerShortName and GroupLabel.OwnerShortName(contact.ownerProfileId)
      or contact.ownerProfileId
    label = ownerName .. " — " .. label
  end
  -- chip shows the canonical channel type only when it adds information —
  -- i.e. when the resolved title is different (custom BN group name,
  -- community name, or a specific guild name). Suppress it when the title
  -- already is the canonical label ("Party [Party]" → "Party").
  local canonical = GroupLabel.LabelForChannel(channel)
  local chip = nil
  if canonical ~= "" and canonical ~= label then
    chip = canonical
  end

  return {
    isGroup = true,
    title = label,
    showPresenceDot = false,
    showFactionIcon = false,
    showStatusLine = false,
    channelChip = chip,
  }
end

ns.ConversationPaneGroupHeaderViewModel = GroupHeaderViewModel
return GroupHeaderViewModel
