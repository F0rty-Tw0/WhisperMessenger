local ContactsTabFilter = require("WhisperMessenger.UI.ContactsList.ContactsTabFilter")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

local function makeItem(channel)
  return { channel = channel, displayName = "test", conversationKey = "k" }
end

return function()
  -- test_filter_whispers_keeps_only_non_group_channels
  do
    local items = {
      makeItem(ChannelType.WHISPER),
      makeItem(ChannelType.BN_WHISPER),
      makeItem(ChannelType.PARTY),
      makeItem(ChannelType.INSTANCE_CHAT),
      makeItem(nil), -- legacy untagged → treated as whisper
    }
    local result = ContactsTabFilter.FilterWhispers(items)
    assert(#result == 3, "FilterWhispers should keep 3 items (WHISPER, BN_WHISPER, nil), got: " .. #result)
    assert(result[1].channel == ChannelType.WHISPER, "first should be WHISPER")
    assert(result[2].channel == ChannelType.BN_WHISPER, "second should be BN_WHISPER")
    assert(result[3].channel == nil, "third should be nil-channel legacy")
  end

  -- test_filter_groups_keeps_only_group_channels
  do
    local items = {
      makeItem(ChannelType.WHISPER),
      makeItem(ChannelType.BN_WHISPER),
      makeItem(ChannelType.PARTY),
      makeItem(ChannelType.INSTANCE_CHAT),
      makeItem(ChannelType.BN_CONVERSATION),
      makeItem(nil),
    }
    local result = ContactsTabFilter.FilterGroups(items)
    assert(#result == 3, "FilterGroups should keep 3 items (PARTY, INSTANCE_CHAT, BN_CONVERSATION), got: " .. #result)
  end

  -- test_filter_whispers_empty_input
  do
    local result = ContactsTabFilter.FilterWhispers({})
    assert(#result == 0, "FilterWhispers on empty should return empty")
  end

  -- test_filter_groups_empty_input
  do
    local result = ContactsTabFilter.FilterGroups({})
    assert(#result == 0, "FilterGroups on empty should return empty")
  end

  -- test_apply_mode_whisper_mode_returns_filtered_whispers
  do
    local items = {
      makeItem(ChannelType.WHISPER),
      makeItem(ChannelType.PARTY),
    }
    local result = ContactsTabFilter.Apply(items, "whispers", true)
    assert(#result == 1, "whisper mode should return 1 item, got: " .. #result)
    assert(result[1].channel == ChannelType.WHISPER, "should be the WHISPER item")
  end

  -- test_apply_mode_groups_mode_returns_filtered_groups
  do
    local items = {
      makeItem(ChannelType.WHISPER),
      makeItem(ChannelType.PARTY),
    }
    local result = ContactsTabFilter.Apply(items, "groups", true)
    assert(#result == 1, "groups mode should return 1 item, got: " .. #result)
    assert(result[1].channel == ChannelType.PARTY, "should be the PARTY item")
  end

  -- test_apply_when_show_group_chats_disabled_always_returns_whispers
  do
    local items = {
      makeItem(ChannelType.WHISPER),
      makeItem(ChannelType.PARTY),
    }
    -- even if mode is "groups", disabled showGroupChats forces whisper view
    local result = ContactsTabFilter.Apply(items, "groups", false)
    assert(#result == 1, "disabled showGroupChats should force whisper filter, got: " .. #result)
    assert(result[1].channel == ChannelType.WHISPER, "should be the WHISPER item")
  end

  -- test_apply_nil_mode_defaults_to_whispers
  do
    local items = {
      makeItem(ChannelType.WHISPER),
      makeItem(ChannelType.PARTY),
    }
    local result = ContactsTabFilter.Apply(items, nil, true)
    assert(#result == 1, "nil mode should default to whispers, got: " .. #result)
    assert(result[1].channel == ChannelType.WHISPER, "should be the WHISPER item")
  end
end
