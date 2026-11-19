-- RowActions.Collect picks the window's row actions out of its flat options,
-- and MessengerWindow.Create hands the table it returns to both wirings.
local RowActions = require("WhisperMessenger.UI.MessengerWindow.RowActions")
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
  "onSeparateCharacter",
  "listMergedCharacters",
}

-- Swaps module[name] for replacement and returns a function that puts it back.
local function stub(module, name, replacement)
  local original = module[name]
  rawset(module, name, replacement)
  return function()
    rawset(module, name, original)
  end
end

-- Records the options a wiring module is created with, then builds it for real.
local function captureCreateOptions(wiring)
  local captured = {}
  local create = wiring.Create
  local restore = stub(wiring, "Create", function(factory, options)
    captured.options = options
    return create(factory, options)
  end)
  return captured, restore
end

return function()
  -- test_collect_carries_every_row_action_from_the_options
  do
    local options = {}
    for _, name in ipairs(ROW_ACTIONS) do
      options[name] = function() end
    end
    local rowActions = RowActions.Collect(options)
    for _, name in ipairs(ROW_ACTIONS) do
      assert(rowActions[name] == options[name], name .. " is the option's own callback")
    end
  end

  -- test_collect_leaves_an_absent_action_absent
  do
    local onPin = function() end
    local rowActions = RowActions.Collect({ onPin = onPin })
    for _, name in ipairs(ROW_ACTIONS) do
      assert(rowActions[name] == (name == "onPin" and onPin or nil), name .. " is only there when the options supplied it")
    end
  end

  -- test_collect_leaves_other_options_out
  do
    local rowActions = RowActions.Collect({ onPin = function() end, onClose = function() end, contacts = {} })
    assert(rowActions.onClose == nil and rowActions.contacts == nil, "other options stay out of the row actions")
    assert(next(RowActions.Collect({ onClose = function() end })) == nil, "no row action in the options gives an empty table")
  end

  -- test_collect_builds_a_table_of_its_own_each_call
  do
    local options = { onPin = function() end }
    local rowActions = RowActions.Collect(options)
    assert(rowActions ~= options, "the options table is not handed back")
    assert(rowActions ~= RowActions.Collect(options), "each call builds a new table")
  end

  -- test_messenger_window_hands_the_collected_table_to_both_wirings
  do
    local windowOptions = { onPin = function() end }
    local collected = { onPin = function() end }
    local seenOptions
    local restoreCollect = stub(RowActions, "Collect", function(options)
      seenOptions = options
      return collected
    end)
    local contacts, restoreContacts = captureCreateOptions(ContactsWiring)
    local conversation, restoreConversation = captureCreateOptions(ConversationWiring)
    local ok, err = pcall(MessengerWindow.Create, FakeUI.NewFactory(), windowOptions)
    restoreCollect()
    restoreContacts()
    restoreConversation()
    assert(ok, err)
    assert(seenOptions == windowOptions, "the window's options are what gets collected from")
    assert(contacts.options.rowActions == collected, "contacts wiring gets the collected table")
    assert(conversation.options.rowActions == collected, "conversation wiring gets the collected table")
  end
end
