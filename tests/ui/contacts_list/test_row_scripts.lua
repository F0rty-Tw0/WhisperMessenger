local RowScripts = require("WhisperMessenger.UI.ContactsList.RowScripts")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()

  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(260, 400)

  -- test_bind_hover_sets_on_enter_and_on_leave
  do
    local row = factory.CreateFrame("Button", nil, parent)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.pinButton = factory.CreateFrame("Button", nil, row)
    row.removeButton = factory.CreateFrame("Button", nil, row)

    local options = {
      onClick = function() end,
      onDragStart = function() end,
      onDragStop = function() end,
    }

    RowScripts.bindHover(row, options)

    assert(row.scripts ~= nil and row.scripts.OnEnter ~= nil, "row should have OnEnter script after bindHover")
    assert(row.scripts.OnLeave ~= nil, "row should have OnLeave script after bindHover")
  end

  -- test_bind_click_calls_on_click_callback
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      pinned = false,
      unreadCount = 0,
    }
    row.item = item

    local clicked = false
    local clickedItem = nil
    local options = {
      onSelect = function(it)
        clicked = true
        clickedItem = it
      end,
    }

    RowScripts.bindClick(row, item, options)

    assert(row.scripts ~= nil and row.scripts.OnClick ~= nil, "row should have OnClick script after bindClick")
    row.scripts.OnClick(row)
    assert(clicked == true, "onSelect callback should be called on OnClick")
    assert(clickedItem == item, "onSelect callback should receive the item, got: " .. tostring(clickedItem))
  end

  -- test_bind_drag_registers_for_pinned_item
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      pinned = true,
      unreadCount = 0,
    }
    row.item = item
    row.rowIndex = 1

    local dragStartCalled = false
    local dragStopCalled = false
    local options = {
      onDragStart = function(_r, _idx)
        dragStartCalled = true
      end,
      onDragStop = function(_r, _idx)
        dragStopCalled = true
      end,
    }

    RowScripts.bindDrag(row, item, options)

    assert(row.dragButtons ~= nil, "pinned row should be registered for drag")
    assert(row.scripts ~= nil and row.scripts.OnDragStart ~= nil, "pinned row should have OnDragStart script")
    assert(row.scripts.OnDragStop ~= nil, "pinned row should have OnDragStop script")

    row.scripts.OnDragStart(row)
    assert(dragStartCalled == true, "onDragStart callback should be called")

    row.scripts.OnDragStop(row)
    assert(dragStopCalled == true, "onDragStop callback should be called")
  end

  -- test_bind_drag_skips_non_pinned_item
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = {
      conversationKey = "me::WOW::bob",
      displayName = "Bob",
      pinned = false,
      unreadCount = 0,
    }
    row.item = item
    row.rowIndex = 2

    local options = {
      onDragStart = function() end,
      onDragStop = function() end,
    }

    RowScripts.bindDrag(row, item, options)

    assert(row.dragButtons == nil, "non-pinned row should not be registered for drag")
    assert(row.scripts == nil or row.scripts.OnDragStart == nil, "non-pinned row should not have OnDragStart script")
    assert(row.scripts == nil or row.scripts.OnDragStop == nil, "non-pinned row should not have OnDragStop script")
  end
end
