local BadgeFilter = require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local ContactsTabFilter = require("WhisperMessenger.UI.ContactsList.ContactsTabFilter")
local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

-- Channels tab: while at least one channel is ticked, channel chats leave
-- Groups and show only in their own tab. With none ticked, old channel
-- history falls back to Groups.

local function buildItems(enabledChannels)
  local savedState = {
    settings = { enabledChannels = enabledChannels },
    conversations = {
      ["me::CHANNEL::trade"] = { channel = ChannelType.CHANNEL, displayName = "Trade", unreadCount = 5, lastActivityAt = 3 },
      ["me::COMMUNITY::1"] = { channel = ChannelType.COMMUNITY, title = "Guildies", unreadCount = 2, lastActivityAt = 2 },
      ["me::wow::friend"] = { channel = "WOW", unreadCount = 1, lastActivityAt = 1 },
    },
  }
  local byKey = {}
  local items = DataBuilder.BuildItemsForProfile(savedState, "me")
  for _, item in ipairs(items) do
    byKey[item.conversationKey] = item
  end
  return items, byKey
end

local function keysOf(items)
  local keys = {}
  for _, item in ipairs(items) do
    keys[#keys + 1] = item.conversationKey
  end
  table.sort(keys)
  return table.concat(keys, ",")
end

return function()
  -- test_channel_chat_belongs_to_channels_tab_while_a_channel_is_ticked
  do
    local _, byKey = buildItems({ trade = true })
    assert(ContactsTabFilter.ModeOf(byKey["me::CHANNEL::trade"]) == "channels", "channel chat sits in Channels")
    assert(ContactsTabFilter.ModeOf(byKey["me::COMMUNITY::1"]) == "groups", "community stays in Groups")
  end

  -- test_groups_tab_drops_channel_chats_while_channels_tab_shows
  do
    local items = buildItems({ trade = true })
    local groups = ContactsTabFilter.Apply(items, "groups", true)
    assert(keysOf(groups) == "me::COMMUNITY::1", "Groups lists only the community, got " .. keysOf(groups))
  end

  -- test_channels_tab_lists_channel_chats_even_with_group_chats_off
  do
    local items = buildItems({ trade = true })
    local channels = ContactsTabFilter.Apply(items, "channels", false)
    assert(keysOf(channels) == "me::CHANNEL::trade", "Channels lists the channel chat, got " .. keysOf(channels))
    local whispers = ContactsTabFilter.Apply(items, "whispers", false)
    assert(keysOf(whispers) == "me::wow::friend", "Whispers keeps only whispers, got " .. keysOf(whispers))
  end

  -- test_no_ticked_channel_falls_back_to_groups
  do
    local items, byKey = buildItems({ trade = false })
    assert(ContactsTabFilter.ModeOf(byKey["me::CHANNEL::trade"]) == "groups", "no channel ticked: channel history is in Groups")
    local groups = ContactsTabFilter.Apply(items, "groups", true)
    assert(keysOf(groups) == "me::CHANNEL::trade,me::COMMUNITY::1", "Groups shows the old channel history, got " .. keysOf(groups))
  end

  -- test_channel_unread_counts_on_channels_tab_only
  do
    local items = buildItems({ trade = true })
    assert(BadgeFilter.SumChannelUnread(items) == 5, "Channels tab counts channel chats")
    assert(BadgeFilter.SumGroupUnread(items) == 2, "Groups tab no longer counts channel chats")
    assert(BadgeFilter.SumWhisperUnread(items) == 1, "whisper badge unchanged")
  end

  -- test_channel_unread_stays_on_groups_without_channels_tab
  do
    local items = buildItems({})
    assert(BadgeFilter.SumChannelUnread(items) == 0, "no Channels tab: nothing counted there")
    assert(BadgeFilter.SumGroupUnread(items) == 7, "no Channels tab: Groups counts channel history")
  end
end
