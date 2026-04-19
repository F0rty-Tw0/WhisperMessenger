local GroupLabel = require("WhisperMessenger.UI.ContactsList.GroupLabel")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

return function()
  -- test_party_returns_Party
  do
    local label = GroupLabel.LabelForChannel(ChannelType.PARTY)
    assert(label == "Party", "PARTY should produce 'Party', got: " .. tostring(label))
  end

  -- test_instance_chat_returns_Instance_BG
  do
    local label = GroupLabel.LabelForChannel(ChannelType.INSTANCE_CHAT)
    assert(label == "Instance (BG)", "INSTANCE_CHAT should produce 'Instance (BG)', got: " .. tostring(label))
  end

  -- test_bn_conversation_no_title_returns_BattleNet_Group
  do
    local label = GroupLabel.LabelForChannel(ChannelType.BN_CONVERSATION)
    assert(label == "Battle.net Group", "BN_CONVERSATION should produce 'Battle.net Group', got: " .. tostring(label))
  end

  -- test_raid_returns_Raid
  do
    local label = GroupLabel.LabelForChannel(ChannelType.RAID)
    assert(label == "Raid", "RAID should produce 'Raid', got: " .. tostring(label))
  end

  -- test_guild_returns_Guild
  do
    local label = GroupLabel.LabelForChannel(ChannelType.GUILD)
    assert(label == "Guild", "GUILD should produce 'Guild', got: " .. tostring(label))
  end

  -- test_officer_returns_Officer
  do
    local label = GroupLabel.LabelForChannel(ChannelType.OFFICER)
    assert(label == "Officer", "OFFICER should produce 'Officer', got: " .. tostring(label))
  end

  -- test_channel_returns_Channel
  do
    local label = GroupLabel.LabelForChannel(ChannelType.CHANNEL)
    assert(label == "Channel", "CHANNEL should produce 'Channel', got: " .. tostring(label))
  end

  -- test_community_returns_Community
  do
    local label = GroupLabel.LabelForChannel(ChannelType.COMMUNITY)
    assert(label == "Community", "COMMUNITY should produce 'Community', got: " .. tostring(label))
  end

  -- test_nil_channel_returns_empty_string
  do
    local label = GroupLabel.LabelForChannel(nil)
    assert(label == "", "nil channel should produce '', got: " .. tostring(label))
  end

  -- test_whisper_channel_returns_empty_string
  do
    local label = GroupLabel.LabelForChannel(ChannelType.WHISPER)
    assert(label == "", "WHISPER channel should produce '', got: " .. tostring(label))
  end

  -- test_bn_whisper_channel_returns_empty_string
  do
    local label = GroupLabel.LabelForChannel(ChannelType.BN_WHISPER)
    assert(label == "", "BN_WHISPER channel should produce '', got: " .. tostring(label))
  end

  -- test_conversation_with_title_uses_title_for_bn_conversation
  do
    local label = GroupLabel.LabelForChannelAndTitle(ChannelType.BN_CONVERSATION, "My Group")
    assert(label == "My Group", "BN_CONVERSATION with title should use title, got: " .. tostring(label))
  end

  -- test_conversation_with_empty_title_falls_back_to_default
  do
    local label = GroupLabel.LabelForChannelAndTitle(ChannelType.BN_CONVERSATION, "")
    assert(label == "Battle.net Group", "BN_CONVERSATION with empty title should fall back, got: " .. tostring(label))
  end

  -- test_conversation_with_nil_title_falls_back_to_default
  do
    local label = GroupLabel.LabelForChannelAndTitle(ChannelType.BN_CONVERSATION, nil)
    assert(label == "Battle.net Group", "BN_CONVERSATION with nil title should fall back, got: " .. tostring(label))
  end
end
