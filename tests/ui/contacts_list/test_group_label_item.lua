local GroupLabel = require("WhisperMessenger.UI.ContactsList.GroupLabel")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

return function()
  -- test_group_channels_are_group_items
  assert(GroupLabel.IsGroupItem({ channel = ChannelType.GUILD }) == true, "guild is a group")
  assert(GroupLabel.IsGroupItem({ channel = ChannelType.PARTY }) == true, "party is a group")

  -- test_whispers_and_legacy_channels_are_not_group_items
  assert(GroupLabel.IsGroupItem({ channel = "WOW" }) == false, "WoW whisper is not a group")
  assert(GroupLabel.IsGroupItem({ channel = "BN" }) == false, "BNet whisper is not a group")
  assert(GroupLabel.IsGroupItem(nil) == false, "nil item is not a group")

  -- test_for_item_uses_the_channel_title
  local community = GroupLabel.ForItem({ channel = ChannelType.COMMUNITY, title = "Raiders" })
  assert(community == "Raiders", "community row is labelled by its title, got " .. tostring(community))

  -- test_for_item_prefixes_another_characters_chat
  local guild = GroupLabel.ForItem({ channel = ChannelType.GUILD, ownerProfileId = "jaina-proudmoore" })
  assert(guild == "Jaina - Guild", "foreign guild chat names its owner, got " .. tostring(guild))

  -- test_for_item_falls_back_to_the_display_name
  local unknown = GroupLabel.ForItem({ channel = "SOMETHING", displayName = "Fallback" })
  assert(unknown == "Fallback", "unlabelled channel falls back to the display name, got " .. tostring(unknown))
end
