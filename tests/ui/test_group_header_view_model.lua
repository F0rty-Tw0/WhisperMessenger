local GroupHeaderViewModel = require("WhisperMessenger.UI.ConversationPane.GroupHeaderViewModel")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

return function()
  -- test_whisper_contact_returns_whisper_mode
  do
    local contact = {
      displayName = "Jaina",
      classTag = "MAGE",
      factionName = "Alliance",
      channel = ChannelType.WHISPER,
    }
    local vm = GroupHeaderViewModel.Build(contact, nil)
    assert(vm.isGroup == false, "WHISPER should produce isGroup=false")
    assert(vm.title == "Jaina", "title should be displayName for whisper")
    assert(vm.showPresenceDot == true, "whisper should show presence dot")
    assert(vm.showFactionIcon == true, "whisper should show faction icon")
    assert(vm.showStatusLine == true, "whisper should show status line")
    assert(vm.channelChip == nil, "whisper should have no channel chip")
  end

  -- test_bn_whisper_contact_returns_whisper_mode
  do
    local contact = {
      displayName = "BnetFriend#1234",
      classTag = nil,
      factionName = nil,
      channel = ChannelType.BN_WHISPER,
    }
    local vm = GroupHeaderViewModel.Build(contact, nil)
    assert(vm.isGroup == false, "BN_WHISPER should produce isGroup=false")
    assert(vm.showPresenceDot == true, "BN_WHISPER should show presence dot")
  end

  -- test_nil_channel_treated_as_whisper
  do
    local contact = {
      displayName = "Legacy",
      channel = nil,
    }
    local vm = GroupHeaderViewModel.Build(contact, nil)
    assert(vm.isGroup == false, "nil channel should produce isGroup=false")
    assert(vm.showPresenceDot == true, "nil channel (legacy whisper) should show presence dot")
  end

  -- test_party_contact_returns_group_mode
  do
    local contact = {
      displayName = "Party",
      channel = ChannelType.PARTY,
    }
    local vm = GroupHeaderViewModel.Build(contact, nil)
    assert(vm.isGroup == true, "PARTY should produce isGroup=true")
    assert(vm.title == "Party", "title should be 'Party' channel label")
    assert(vm.showPresenceDot == false, "group should NOT show presence dot")
    assert(vm.showFactionIcon == false, "group should NOT show faction icon")
    assert(vm.showStatusLine == false, "group should NOT show status line")
    assert(vm.channelChip == nil, "PARTY chip suppressed when it would duplicate the title")
  end

  -- test_instance_chat_returns_correct_label
  do
    local contact = {
      displayName = "InstanceChat",
      channel = ChannelType.INSTANCE_CHAT,
    }
    local vm = GroupHeaderViewModel.Build(contact, nil)
    assert(vm.isGroup == true, "INSTANCE_CHAT should produce isGroup=true")
    assert(vm.title == "Instance (BG)", "title should be 'Instance (BG)'")
    assert(vm.channelChip == nil, "INSTANCE chip suppressed when it would duplicate the title")
  end

  -- test_bn_conversation_no_title_returns_battle_net_group
  do
    local contact = {
      displayName = "BN Group",
      channel = ChannelType.BN_CONVERSATION,
    }
    local conversation = { title = nil }
    local vm = GroupHeaderViewModel.Build(contact, conversation)
    assert(vm.isGroup == true, "BN_CONVERSATION should produce isGroup=true")
    assert(vm.title == "Battle.net Group", "title should be 'Battle.net Group' when no conv.title")
    assert(vm.channelChip == nil, "chip suppressed when title already is the canonical label")
  end

  -- test_bn_conversation_with_title_uses_title
  do
    local contact = {
      displayName = "BN Group",
      channel = ChannelType.BN_CONVERSATION,
    }
    local conversation = { title = "Raid Planning" }
    local vm = GroupHeaderViewModel.Build(contact, conversation)
    assert(vm.title == "Raid Planning", "title should use conversation.title when set")
    assert(vm.channelChip == "Battle.net Group", "chip adds channel context when title is a custom name")
  end

  -- test_nil_contact_returns_nil
  do
    local vm = GroupHeaderViewModel.Build(nil, nil)
    assert(vm == nil, "nil contact should return nil view-model")
  end

  -- test_raid_returns_correct_label
  do
    local contact = { channel = ChannelType.RAID, displayName = "Raid" }
    local vm = GroupHeaderViewModel.Build(contact, nil)
    assert(vm.isGroup == true, "RAID should produce isGroup=true")
    assert(vm.title == "Raid", "RAID title should be 'Raid'")
    assert(vm.channelChip == nil, "RAID chip suppressed when it would duplicate the title")
  end

  -- test_guild_with_guild_name_uses_name_and_keeps_chip
  do
    local savedGetGuildInfo = _G.GetGuildInfo
    _G.GetGuildInfo = function()
      return "Everlasting Vigil"
    end

    local contact = { channel = ChannelType.GUILD, displayName = "Guild" }
    local vm = GroupHeaderViewModel.Build(contact, nil)
    assert(vm.title == "Everlasting Vigil", "GUILD title should use player's guild name")
    assert(vm.channelChip == "Guild", "GUILD chip stays visible to annotate the guild-name title")

    _G.GetGuildInfo = savedGetGuildInfo
  end

  -- test_guild_without_guild_name_falls_back_to_Guild_and_hides_chip
  do
    local savedGetGuildInfo = _G.GetGuildInfo
    _G.GetGuildInfo = function()
      return nil
    end

    local contact = { channel = ChannelType.GUILD, displayName = "Guild" }
    local vm = GroupHeaderViewModel.Build(contact, nil)
    assert(vm.title == "Guild", "GUILD title falls back to 'Guild' when not in a guild")
    assert(vm.channelChip == nil, "GUILD chip suppressed when title equals 'Guild'")

    _G.GetGuildInfo = savedGetGuildInfo
  end

  -- test_foreign_owner_group_prefixes_title_with_owner_name
  do
    local savedGetGuildInfo = _G.GetGuildInfo
    _G.GetGuildInfo = function()
      return "Current Guild"
    end

    local partyContact = {
      channel = ChannelType.PARTY,
      displayName = "Party",
      ownerProfileId = "jaina-proudmoore",
    }
    local vm = GroupHeaderViewModel.Build(partyContact, nil)
    assert(vm.title == "Jaina — Party", "foreign-owner party title should be prefixed; got: " .. tostring(vm.title))

    -- Foreign guild must NOT adopt the current char's live guild name —
    -- it's another character's guild history. Title should be the
    -- canonical "Guild" with owner prefix.
    local guildContact = {
      channel = ChannelType.GUILD,
      displayName = "Guild",
      ownerProfileId = "thrall-draenor",
    }
    local guildVm = GroupHeaderViewModel.Build(guildContact, nil)
    assert(guildVm.title == "Thrall — Guild", "foreign-owner guild should NOT use current char's guild name; got: " .. tostring(guildVm.title))

    _G.GetGuildInfo = savedGetGuildInfo
  end
end
