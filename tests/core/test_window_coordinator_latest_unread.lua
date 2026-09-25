local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")

-- Opening the window jumps to the latest unread chat, but never to a muted
-- chat or a message request (they stay quiet). A mention breaks through mute.
return function()
  local contacts = {}
  local coordinator = WindowCoordinator.Create({
    runtime = {},
    buildContacts = function()
      return contacts
    end,
  })

  -- test_skips_muted_and_request_conversations
  contacts = {
    { conversationKey = "muted", channel = "WOW", unreadCount = 3, muted = true },
    { conversationKey = "request", channel = "WOW", unreadCount = 2, isRequest = true },
    { conversationKey = "normal", channel = "WOW", unreadCount = 1 },
  }
  assert(coordinator.findLatestUnreadKey() == "normal", "got " .. tostring(coordinator.findLatestUnreadKey()))

  -- test_nothing_when_only_quiet_conversations_are_unread
  contacts = { contacts[1], contacts[2] }
  assert(coordinator.findLatestUnreadKey() == nil, "quiet chats never steal the selection")

  -- test_muted_group_with_mention_counts
  contacts = { { conversationKey = "party", channel = "PARTY", unreadCount = 1, muted = true, hasUnreadMention = true } }
  assert(coordinator.findLatestUnreadKey() == "party", "a mention breaks through mute")
end
