-- The contacts controller takes the row actions as one table
-- (options.rowActions) and hands them to the contact row's menu.
local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local ContactsController = require("WhisperMessenger.UI.MessengerWindow.ContactsController")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")

local ITEM = { conversationKey = "me::WOW::arthas", channel = "WOW", displayName = "Arthas", unreadCount = 0, lastActivityAt = 1 }

-- Right-clicks the first row and returns what its menu was opened with.
local function openRowMenu(options)
  local factory = FakeUI.NewFactory()
  local pane = factory.CreateFrame("Frame", nil, nil)
  pane:SetSize(260, 400)
  local view = ScrollView.Create(factory, pane, { width = 260, height = 400 })
  local controller = ContactsController.Create(factory, view, {}, options)
  local row = controller.refresh({ ITEM }, nil, true)[1]
  local opened
  local open = ContextMenu.Open
  rawset(ContextMenu, "Open", function(item, _anchor, onMarkUnread, onUpdatePrefs, rowActions)
    opened = { item = item, onMarkUnread = onMarkUnread, onUpdatePrefs = onUpdatePrefs, rowActions = rowActions }
    return true
  end)
  row.scripts.OnClick(row, "RightButton")
  rawset(ContextMenu, "Open", open)
  return opened
end

return function()
  -- test_row_menu_calls_the_actions_from_the_row_actions_table
  do
    local calls = {}
    local function record(name)
      return function(...)
        calls[#calls + 1] = { name, ... }
      end
    end
    local opened = openRowMenu({
      rowActions = {
        onPin = record("onPin"),
        onRemove = record("onRemove"),
        onMarkUnread = record("onMarkUnread"),
        onUpdatePrefs = record("onUpdatePrefs"),
      },
    })
    local changes = { muted = true }
    opened.rowActions.onPin(ITEM)
    opened.rowActions.onRemove(ITEM)
    opened.onMarkUnread(ITEM)
    opened.onUpdatePrefs(ITEM, changes)
    assert(#calls == 4, "each menu action reached its callback, got " .. #calls)
    assert(calls[1][1] == "onPin" and calls[1][2] == ITEM, "pin carries the row's item")
    assert(calls[2][1] == "onRemove" and calls[2][2] == ITEM, "remove carries the row's item")
    assert(calls[3][1] == "onMarkUnread" and calls[3][2] == ITEM, "mark unread carries the row's item")
    assert(calls[4][1] == "onUpdatePrefs" and calls[4][2] == ITEM and calls[4][3] == changes, "prefs carry the item and the changes")
  end

  -- test_row_menu_gets_the_block_and_who_actions_from_the_row_actions_table
  do
    local rowActions = {
      onIgnorePlayer = function() end,
      onUnblockPlayer = function() end,
      isPlayerBlocked = function() end,
      whoPlayer = function() end,
    }
    local opened = openRowMenu({ rowActions = rowActions })
    for name, action in pairs(rowActions) do
      assert(opened.rowActions[name] == action, name .. " is the supplied callback")
    end
  end

  -- test_row_menu_gets_a_row_action_the_controller_does_not_name
  do
    local onSomethingNew = function() end
    local opened = openRowMenu({ rowActions = { onSomethingNew = onSomethingNew } })
    assert(opened.rowActions.onSomethingNew == onSomethingNew, "a new row action needs no line in the controller")
  end

  -- test_actions_outside_the_row_actions_table_are_not_read
  do
    local opened = openRowMenu({ onIgnorePlayer = function() end, whoPlayer = function() end })
    assert(opened.rowActions.onIgnorePlayer == nil and opened.rowActions.whoPlayer == nil, "only options.rowActions feeds the row")
  end

  -- test_absent_block_action_stays_absent_in_the_row_menu
  do
    local opened = openRowMenu({ rowActions = {} })
    assert(opened.rowActions.onIgnorePlayer == nil, "no Block… entry without onIgnorePlayer")
    assert(opened.rowActions.onUnblockPlayer == nil and opened.rowActions.isPlayerBlocked == nil, "no Unblock entry either")
    assert(opened.rowActions.whoPlayer == nil, "no /who on shift-click")
  end
end
