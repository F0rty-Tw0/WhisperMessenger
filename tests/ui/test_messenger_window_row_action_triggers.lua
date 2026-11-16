-- The window's Pin, Remove and invite callbacks are reached from where a
-- player triggers them: the contact row's hover buttons and the chat
-- header's invite badge.
local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local FakeUI = require("tests.helpers.fake_ui")

local ARTHAS_KEY = "me::WOW::arthas"

local function click(button)
  button:GetScript("OnClick")(button, "LeftButton")
end

-- Builds the real window on one whisper contact, selected, and merges the
-- callbacks under test into its options.
local function createWindow(callbacks)
  local contacts = ContactsList.BuildItems({
    [ARTHAS_KEY] = { displayName = "Arthas", channel = "WOW", lastActivityAt = 1, unreadCount = 0, messages = {} },
  })
  local windowOptions = { contacts = contacts, selectedContact = contacts[1], conversation = { messages = {} } }
  for name, callback in pairs(callbacks) do
    windowOptions[name] = callback
  end
  return MessengerWindow.Create(FakeUI.NewFactory(), windowOptions), contacts[1]
end

return function()
  -- test_row_pin_button_click_reaches_the_window_on_pin
  do
    local pinned = {}
    local window, contact = createWindow({
      onPin = function(item)
        table.insert(pinned, item)
      end,
    })
    click(window.contacts.rows[1].pinButton)
    assert(#pinned == 1 and pinned[1] == contact, "the pin button runs onPin with the row's contact")
  end

  -- test_row_remove_button_click_reaches_the_window_on_remove
  do
    local removed = {}
    local window, contact = createWindow({
      onRemove = function(item)
        table.insert(removed, item)
      end,
    })
    click(window.contacts.rows[1].removeButton)
    assert(#removed == 1 and removed[1] == contact, "the remove button runs onRemove with the row's contact")
  end

  -- test_header_invite_badge_click_reaches_the_window_on_invite_contact
  do
    local invited = {}
    local window, contact = createWindow({
      onInviteContact = function(target)
        table.insert(invited, target)
      end,
    })
    click(window.conversation.headerAddonBadgeButton)
    assert(#invited == 1 and invited[1] == contact, "the invite badge runs onInviteContact with the open contact")
  end

  -- test_header_invite_badge_hides_when_the_window_disallows_invites
  do
    local asked = 0
    local window = createWindow({
      canInviteContact = function()
        asked = asked + 1
        return false
      end,
    })
    assert(asked > 0, "the header asks the window's canInviteContact")
    assert(window.conversation.headerAddonBadge:IsShown() == false, "no invite badge while canInviteContact says no")
  end

  -- test_header_invite_badge_shows_when_the_window_allows_invites
  do
    local window = createWindow({
      canInviteContact = function()
        return true
      end,
    })
    assert(window.conversation.headerAddonBadge:IsShown() == true, "invite badge shows while canInviteContact says yes")
  end
end
