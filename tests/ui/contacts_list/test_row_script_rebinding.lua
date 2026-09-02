-- Contact rows are re-bound on every background status refresh. Binding fresh
-- closures each time churned memory for no visible change, so the scripts are
-- created once per row and read their state (item, index, callbacks) live.

local ContactsList = require("WhisperMessenger.UI.ContactsList")
local ContactsController = require("WhisperMessenger.UI.MessengerWindow.ContactsController")
local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local FakeUI = require("tests.helpers.fake_ui")

local function makeItem(key, name, pinned)
  return {
    conversationKey = key,
    displayName = name,
    lastPreview = "preview",
    unreadCount = 0,
    lastActivityAt = 100,
    channel = "WOW",
    pinned = pinned or false,
    sortOrder = 1,
  }
end

return function()
  ----------------------------------------------------------------------------
  -- Re-binding the same rows keeps the very same script closures.
  ----------------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(260, 400)
    local items = { makeItem("me::WOW::alice", "Alice"), makeItem("me::WOW::bob", "Bob") }
    local options = { onSelect = function() end }

    local rows = ContactsList.Refresh(factory, parent, nil, items, options)
    local firstClick = rows[1]:GetScript("OnClick")
    local firstEnter = rows[1]:GetScript("OnEnter")
    local firstLeave = rows[1]:GetScript("OnLeave")
    assert(type(firstClick) == "function", "expected an OnClick handler after the first refresh")

    ContactsList.Refresh(factory, parent, rows, items, options)
    assert(rows[1]:GetScript("OnClick") == firstClick, "OnClick should be the same closure after a second refresh")
    assert(rows[1]:GetScript("OnEnter") == firstEnter, "OnEnter should be the same closure after a second refresh")
    assert(rows[1]:GetScript("OnLeave") == firstLeave, "OnLeave should be the same closure after a second refresh")
  end

  ----------------------------------------------------------------------------
  -- The reused OnClick closure calls whichever callback the latest bind supplied.
  ----------------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(260, 400)
    local items = { makeItem("me::WOW::alice", "Alice") }

    local firstSelected
    local rows = ContactsList.Refresh(factory, parent, nil, items, {
      onSelect = function(item)
        firstSelected = item
      end,
    })

    local secondSelected
    ContactsList.Refresh(factory, parent, rows, items, {
      onSelect = function(item)
        secondSelected = item
      end,
    })

    rows[1]:GetScript("OnClick")(rows[1], "LeftButton")
    assert(firstSelected == nil, "the stale callback should not fire")
    assert(secondSelected == items[1], "the latest callback should receive the clicked item")
  end

  ----------------------------------------------------------------------------
  -- Drag follows the pinned flag of whatever item the row currently holds.
  ----------------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(260, 400)

    local dragged
    local options = {
      onDragStart = function(_row, index)
        dragged = index
      end,
    }

    local pinnedItem = makeItem("me::WOW::alice", "Alice", true)
    local unpinnedItem = makeItem("me::WOW::bob", "Bob", false)

    local row = RowView.bindRow(factory, parent, nil, 1, pinnedItem, options)
    assert(row.dragButtons ~= nil, "a pinned row should register for drag")

    row = RowView.bindRow(factory, parent, row, 2, unpinnedItem, options)
    assert(row.dragButtons == nil, "an unpinned row should unregister drag")
    row:GetScript("OnDragStart")(row)
    assert(dragged == nil, "OnDragStart should no-op while the row holds an unpinned item")

    row = RowView.bindRow(factory, parent, row, 3, pinnedItem, options)
    assert(row.dragButtons ~= nil, "re-pinning should register for drag again")
    row:GetScript("OnDragStart")(row)
    assert(dragged == 3, "OnDragStart should report the row's current index, got " .. tostring(dragged))
  end

  ----------------------------------------------------------------------------
  -- The controller hands the list one options table and mutates it in place.
  ----------------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent:SetSize(260, 400)
    local contactsView = ScrollView.Create(factory, parent, { width = 260, height = 400, step = 44 })

    local originalRefresh = ContactsList.Refresh
    local seen = {}
    ---@diagnostic disable-next-line: duplicate-set-field
    ContactsList.Refresh = function(_factory, _parent, rows, _items, options)
      seen[#seen + 1] = { options = options, selectedConversationKey = options.selectedConversationKey }
      return rows or {}
    end

    local ok, err = pcall(function()
      local controller = ContactsController.Create(factory, contactsView, { makeItem("me::WOW::alice", "Alice") }, {})
      controller.refresh(nil, "me::WOW::alice")
      controller.refresh(nil, "me::WOW::bob")
    end)
    ContactsList.Refresh = originalRefresh
    if not ok then
      error(err)
    end

    assert(#seen >= 2, "expected at least two Refresh calls, got " .. #seen)
    local last = seen[#seen]
    local previous = seen[#seen - 1]
    assert(last.options == previous.options, "the controller should reuse one options table across refreshes")
    assert(previous.selectedConversationKey == "me::WOW::alice", "first refresh should carry the first selection")
    assert(last.selectedConversationKey == "me::WOW::bob", "second refresh should carry the updated selection")
  end
end
