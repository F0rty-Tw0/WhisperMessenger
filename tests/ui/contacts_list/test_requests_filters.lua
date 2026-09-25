local BadgeFilter = require("WhisperMessenger.UI.ToggleIcon.BadgeFilter")
local ContactsTabFilter = require("WhisperMessenger.UI.ContactsList.ContactsTabFilter")
local DataBuilder = require("WhisperMessenger.UI.ContactsList.DataBuilder")

-- Requests inbox: requests leave the Whispers tab and every aggregate badge,
-- and show only in their own tab.
return function()
  local contacts = {
    { conversationKey = "a", channel = "WOW", unreadCount = 2 },
    { conversationKey = "b", channel = "WOW", unreadCount = 4, isRequest = true },
    { conversationKey = "c", channel = "GUILD", unreadCount = 3 },
  }

  -- test_request_unread_is_out_of_whisper_badge
  assert(BadgeFilter.SumWhisperUnread(contacts) == 2, "request excluded from widget/minimap/Whispers counts")

  -- test_request_unread_has_its_own_sum
  assert(BadgeFilter.SumRequestUnread(contacts) == 4, "Requests tab counts only requests")

  -- test_whispers_tab_hides_requests
  local whispers = ContactsTabFilter.Apply(contacts, "whispers", true)
  assert(#whispers == 1 and whispers[1].conversationKey == "a", "Whispers tab hides requests")

  -- test_requests_tab_shows_only_requests
  local requests = ContactsTabFilter.Apply(contacts, "requests", false)
  assert(#requests == 1 and requests[1].conversationKey == "b", "Requests tab lists requests, even with groups off")

  -- test_mode_of_item
  assert(ContactsTabFilter.ModeOf(contacts[1]) == "whispers", "plain whisper")
  assert(ContactsTabFilter.ModeOf(contacts[2]) == "requests", "request")
  assert(ContactsTabFilter.ModeOf(contacts[3]) == "groups", "group")

  -- test_data_builder_marks_requests_only_while_inbox_is_on
  local savedState = {
    settings = { requestsInbox = true },
    conversations = {
      ["me::wow::stranger"] = { channel = "WOW", request = true, lastActivityAt = 1 },
      ["me::wow::friend"] = { channel = "WOW", lastActivityAt = 2 },
    },
  }
  local items = DataBuilder.BuildItemsForProfile(savedState, "me")
  local byKey = {}
  for _, item in ipairs(items) do
    byKey[item.conversationKey] = item
  end
  assert(byKey["me::wow::stranger"].isRequest == true, "flagged conversation is a request item")
  assert(not byKey["me::wow::friend"].isRequest, "unflagged conversation is a whisper item")
  savedState.settings.requestsInbox = false
  items = DataBuilder.BuildItemsForProfile(savedState, "me")
  for _, item in ipairs(items) do
    assert(not item.isRequest, "inbox off: every request is back in Whispers")
  end
end
