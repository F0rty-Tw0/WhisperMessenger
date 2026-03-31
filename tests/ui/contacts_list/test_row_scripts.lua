local RowScripts = require("WhisperMessenger.UI.ContactsList.RowScripts")
local ContextMenu = require("WhisperMessenger.UI.ContactsList.ContextMenu")
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

  -- test_bind_click_registers_right_button
  do
    local row = factory.CreateFrame("Button", nil, parent)
    local item = {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      pinned = false,
      unreadCount = 0,
    }
    row.item = item

    local registered = nil
    row.RegisterForClicks = function(_self, ...)
      registered = { ... }
    end

    RowScripts.bindClick(row, item, { onSelect = function() end })

    assert(registered ~= nil, "bindClick should register click buttons")
    assert(registered[1] == "LeftButtonUp", "bindClick should register LeftButtonUp")
    assert(registered[2] == "RightButtonUp", "bindClick should register RightButtonUp")
  end

  -- test_bind_click_right_button_opens_context_menu_without_selecting
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
    local menuOpenedWith = nil
    local originalOpen = ContextMenu.Open
    ContextMenu.Open = function(openItem, openAnchor)
      menuOpenedWith = { item = openItem, anchor = openAnchor }
      return true
    end

    local options = {
      onSelect = function()
        clicked = true
      end,
    }

    RowScripts.bindClick(row, item, options)
    row.scripts.OnClick(row, "RightButton")

    ContextMenu.Open = originalOpen

    assert(clicked == false, "onSelect should not be called on right-click")
    assert(menuOpenedWith ~= nil, "right-click should open the context menu")
    assert(menuOpenedWith.item == item, "context menu should receive row item")
    assert(menuOpenedWith.anchor == row, "context menu should anchor to row frame")
  end

  -- test_bind_click_right_button_falls_back_to_select_when_menu_fails
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
    local originalOpen = ContextMenu.Open
    ContextMenu.Open = function()
      return false
    end

    local options = {
      onSelect = function()
        clicked = true
      end,
    }

    RowScripts.bindClick(row, item, options)
    row.scripts.OnClick(row, "RightButton")

    ContextMenu.Open = originalOpen

    assert(clicked == true, "onSelect should run when right-click menu could not be opened")
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
