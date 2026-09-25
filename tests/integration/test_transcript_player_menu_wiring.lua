local ContactsList = require("WhisperMessenger.UI.ContactsList")
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local PlayerMenu = require("WhisperMessenger.UI.ChatBubble.PlayerMenu")
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")

-- Right-clicking an incoming sender in the transcript opens the player menu
-- for the selected contact, with the window's contact-menu callbacks.
local ARTHAS = "me::WOW::arthas-area52"

return function()
  local incoming = { id = "1", direction = "in", kind = "user", text = "you coming?", sentAt = 10, playerName = "Arthas-Area52" }
  local conversations = {
    [ARTHAS] = { displayName = "Arthas-Area52", channel = "WOW", lastActivityAt = 10, messages = { incoming } },
  }
  local markUnread, updatePrefs = function() end, function() end
  local window = MessengerWindow.Create(FakeUI.NewFactory(), {
    contacts = ContactsList.BuildItems(conversations),
    onSelectConversation = function(conversationKey, item)
      return { selectedContact = item, conversation = conversations[conversationKey] }
    end,
    onMarkUnread = markUnread,
    onUpdatePrefs = updatePrefs,
  })
  local row = window.contacts.rows[1]
  row.scripts.OnClick()

  local sender = FindUI.find(window.frame, function(node)
    return type(node._wmPlayerMenuOpener) == "function" and node.scripts and node.scripts.OnMouseUp ~= nil
  end)
  assert(sender ~= nil, "incoming sender has a player-menu handler")

  local received
  local originalOpen = PlayerMenu.Open
  rawset(PlayerMenu, "Open", function(message, anchor, _contextMenu, conversation)
    received = { message = message, anchor = anchor, conversation = conversation }
    return true
  end)
  sender.scripts.OnMouseUp(sender, "RightButton")
  rawset(PlayerMenu, "Open", originalOpen)

  -- test_sender_right_click_opens_menu_for_selected_contact
  assert(received ~= nil, "right-click reaches PlayerMenu")
  local conversation = received.conversation or {}
  assert(conversation.contact and conversation.contact.conversationKey == ARTHAS, "menu gets the selected contact")
  assert(conversation.onMarkUnread == markUnread and conversation.onUpdatePrefs == updatePrefs, "menu gets the contact-menu callbacks")
end
