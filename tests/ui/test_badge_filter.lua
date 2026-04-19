local BadgeFilter = require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

local function makeContact(channel, unreadCount)
  return { channel = channel, unreadCount = unreadCount or 0, conversationKey = "k" }
end

return function()
  -- test_sum_whisper_unread_counts_only_whisper_and_bn_whisper
  do
    local contacts = {
      makeContact(ChannelType.WHISPER, 3),
      makeContact(ChannelType.BN_WHISPER, 2),
      makeContact(ChannelType.PARTY, 10),
      makeContact(ChannelType.INSTANCE_CHAT, 5),
      makeContact(ChannelType.BN_CONVERSATION, 7),
    }
    local sum = BadgeFilter.SumWhisperUnread(contacts)
    assert(sum == 5, "badge sum should be 5 (3+2), groups excluded; got: " .. tostring(sum))
  end

  -- test_nil_channel_treated_as_whisper
  do
    local contacts = {
      makeContact(nil, 4),
      makeContact(ChannelType.PARTY, 10),
    }
    local sum = BadgeFilter.SumWhisperUnread(contacts)
    assert(sum == 4, "nil channel should count as whisper; got: " .. tostring(sum))
  end

  -- test_empty_contacts_returns_zero
  do
    local sum = BadgeFilter.SumWhisperUnread({})
    assert(sum == 0, "empty contacts should sum to 0; got: " .. tostring(sum))
  end

  -- test_nil_contacts_returns_zero
  do
    local sum = BadgeFilter.SumWhisperUnread(nil)
    assert(sum == 0, "nil contacts should sum to 0; got: " .. tostring(sum))
  end

  -- test_all_group_contacts_returns_zero
  do
    local contacts = {
      makeContact(ChannelType.PARTY, 5),
      makeContact(ChannelType.RAID, 3),
      makeContact(ChannelType.GUILD, 2),
    }
    local sum = BadgeFilter.SumWhisperUnread(contacts)
    assert(sum == 0, "all group contacts should sum to 0; got: " .. tostring(sum))
  end

  -- test_nil_unread_count_treated_as_zero
  do
    local contacts = {
      makeContact(ChannelType.WHISPER, nil),
      makeContact(ChannelType.BN_WHISPER, 2),
    }
    local sum = BadgeFilter.SumWhisperUnread(contacts)
    assert(sum == 2, "nil unreadCount should be treated as 0; got: " .. tostring(sum))
  end

  -- test_over_99_returns_exact_number_not_capped
  do
    -- BadgeFilter just sums; the display cap (99+) is in the Badge UI, not here
    local contacts = {
      makeContact(ChannelType.WHISPER, 60),
      makeContact(ChannelType.BN_WHISPER, 60),
    }
    local sum = BadgeFilter.SumWhisperUnread(contacts)
    assert(sum == 120, "sum should be exact 120, not capped; got: " .. tostring(sum))
  end
end
