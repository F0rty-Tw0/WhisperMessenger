-- MessengerWindow.Create gathers the row actions from its flat options into
-- one table and hands that same table to the contacts wiring (contact row
-- menu) and the conversation wiring (transcript and header menus).
local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ContactsWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ContactsWiring")
local ConversationWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.ConversationWiring")
local FakeUI = require("tests.helpers.fake_ui")

local ROW_ACTIONS = {
  "onPin",
  "onRemove",
  "onMarkUnread",
  "onUpdatePrefs",
  "onIgnorePlayer",
  "onUnblockPlayer",
  "isPlayerBlocked",
  "whoPlayer",
  "onInviteContact",
  "canInviteContact",
}

-- Records the options a wiring module is created with, then builds it for real.
local function captureCreateOptions(wiring)
  local captured = {}
  local create = wiring.Create
  rawset(wiring, "Create", function(factory, options)
    captured.options = options
    return create(factory, options)
  end)
  return captured, function()
    rawset(wiring, "Create", create)
  end
end

-- Returns the row actions handed to the contacts and the conversation wiring.
local function createWindow(windowOptions)
  local contacts, restoreContacts = captureCreateOptions(ContactsWiring)
  local conversation, restoreConversation = captureCreateOptions(ConversationWiring)
  MessengerWindow.Create(FakeUI.NewFactory(), windowOptions)
  restoreContacts()
  restoreConversation()
  return contacts.options.rowActions, conversation.options.rowActions
end

return function()
  -- test_row_actions_table_carries_every_window_callback
  do
    local windowOptions = {}
    for _, name in ipairs(ROW_ACTIONS) do
      windowOptions[name] = function() end
    end
    local rowActions = createWindow(windowOptions)
    assert(type(rowActions) == "table", "contacts wiring gets a row actions table")
    for _, name in ipairs(ROW_ACTIONS) do
      assert(rowActions[name] == windowOptions[name], name .. " is the window's own callback")
    end
  end

  -- test_contact_row_menu_and_transcript_menu_share_one_actions_table
  do
    local contactsRowActions, conversationRowActions = createWindow({ onPin = function() end })
    assert(type(contactsRowActions) == "table", "contacts wiring gets a row actions table")
    assert(contactsRowActions == conversationRowActions, "both wirings get the same table")
  end

  -- test_absent_window_callback_is_absent_from_the_row_actions
  do
    local onPin = function() end
    local rowActions = createWindow({ onPin = onPin })
    for _, name in ipairs(ROW_ACTIONS) do
      assert(rowActions[name] == (name == "onPin" and onPin or nil), name .. " is only there when the window supplied it")
    end
  end

  -- test_row_actions_table_carries_only_row_actions
  do
    local rowActions = createWindow({ onPin = function() end, onClose = function() end, contacts = {} })
    assert(rowActions.onClose == nil and rowActions.contacts == nil, "other window options stay out of the row actions")
  end
end
