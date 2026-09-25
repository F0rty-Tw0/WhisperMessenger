local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

-- The title-bar "Mark all as read" button follows unread across every tab
-- and hands clicks to the window's onMarkAllRead option.
return function()
  local unreadGroupOnly = ContactsList.BuildItems({
    ["me::WOW::arthas"] = { displayName = "Arthas", channel = "WOW", lastActivityAt = 2, unreadCount = 0, messages = {} },
    ["channel::GUILD"] = { displayName = "Guild", channel = "GUILD", lastActivityAt = 1, unreadCount = 3, messages = {} },
  })
  local allRead = ContactsList.BuildItems({
    ["me::WOW::arthas"] = { displayName = "Arthas", channel = "WOW", lastActivityAt = 2, unreadCount = 0, messages = {} },
  })

  local calls = 0
  local window = MessengerWindow.Create(FakeUI.NewFactory(), {
    contacts = unreadGroupOnly,
    onMarkAllRead = function()
      calls = calls + 1
    end,
  })
  local button = window.markAllReadButton

  -- test_unread_on_another_tab_enables_the_button
  assert(button ~= nil, "window exposes the mark all read button")
  assert(button:IsShown() == true, "group unread shows it while the Whispers tab shows")

  -- test_click_reaches_the_window_option
  button:GetScript("OnClick")(button)
  assert(calls == 1, "click runs onMarkAllRead")

  -- test_nothing_unread_hides_the_button
  window.refreshContacts(allRead)
  assert(button:IsShown() == false, "hidden once nothing is unread")
end
