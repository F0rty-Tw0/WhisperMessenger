local RowView = require("WhisperMessenger.UI.ContactsList.RowView")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()

  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  local items = {
    {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      lastPreview = "a",
      unreadCount = 0,
      lastActivityAt = 100,
      channel = "WOW",
      classTag = nil,
      pinned = true,
      sortOrder = 1,
    },
    {
      conversationKey = "me::WOW::bob",
      displayName = "Bob",
      lastPreview = "b",
      unreadCount = 0,
      lastActivityAt = 90,
      channel = "WOW",
      classTag = nil,
      pinned = true,
      sortOrder = 2,
    },
  }

  local options = {
    onSelect = function() end,
    onPin = function() end,
    onRemove = function() end,
    onReorder = function() end,
  }

  -- test_row_is_registered_for_drag
  do
    local row = RowView.bindRow(factory, parent, nil, 1, items[1], options)
    assert(row.dragButtons ~= nil, "row should be registered for drag")
  end

  -- test_row_has_drag_scripts
  do
    local row = RowView.bindRow(factory, parent, nil, 1, items[1], options)
    assert(row.scripts.OnDragStart ~= nil, "row should have OnDragStart")
    assert(row.scripts.OnDragStop ~= nil, "row should have OnDragStop")
  end

  -- test_row_stores_index_for_drag
  do
    local row = RowView.bindRow(factory, parent, nil, 1, items[1], options)
    assert(row.rowIndex == 1, "row should store its index, got: " .. tostring(row.rowIndex))

    local row2 = RowView.bindRow(factory, parent, nil, 2, items[2], options)
    assert(row2.rowIndex == 2, "row2 should store index 2, got: " .. tostring(row2.rowIndex))
  end

  -- test_unpinned_row_has_no_drag_scripts
  do
    local unpinnedItem = {
      conversationKey = "me::WOW::carol",
      displayName = "Carol",
      lastPreview = "c",
      unreadCount = 0,
      lastActivityAt = 80,
      channel = "WOW",
      classTag = nil,
      pinned = false,
      sortOrder = 0,
    }
    local row = RowView.bindRow(factory, parent, nil, 3, unpinnedItem, options)
    assert(row.scripts.OnDragStart == nil, "unpinned row should not have OnDragStart")
    assert(row.scripts.OnDragStop == nil, "unpinned row should not have OnDragStop")
    assert(row.dragButtons == nil, "unpinned row should not be registered for drag")
  end
end
