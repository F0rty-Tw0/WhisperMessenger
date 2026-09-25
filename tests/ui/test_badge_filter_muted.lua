local BadgeFilter = require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")

-- Muted conversations keep their row count but stay out of every aggregate
-- badge (widget, minimap, data broker, Whispers/Groups tabs).
return function()
  local contacts = {
    { channel = "WOW", unreadCount = 2 },
    { channel = "BN", unreadCount = 5, muted = true },
    { channel = "GUILD", unreadCount = 3 },
    { channel = "PARTY", unreadCount = 4, muted = true },
  }

  -- test_muted_whisper_unread_is_excluded
  assert(BadgeFilter.SumWhisperUnread(contacts) == 2, "muted whisper excluded, got " .. BadgeFilter.SumWhisperUnread(contacts))

  -- test_muted_group_unread_is_excluded
  assert(BadgeFilter.SumGroupUnread(contacts) == 3, "muted group excluded, got " .. BadgeFilter.SumGroupUnread(contacts))

  -- test_muted_group_with_unread_mention_counts
  contacts[4].hasUnreadMention = true
  assert(BadgeFilter.SumGroupUnread(contacts) == 7, "a mention breaks through mute, got " .. BadgeFilter.SumGroupUnread(contacts))
end
