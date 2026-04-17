local Theme = require("WhisperMessenger.UI.Theme")
local RowScripts = require("WhisperMessenger.UI.ContactsList.RowScripts")
local ActionButtons = require("WhisperMessenger.UI.ContactsList.ActionButtons")
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
    rawset(ContextMenu, "Open", function(openItem, openAnchor)
      menuOpenedWith = { item = openItem, anchor = openAnchor }
      return true
    end)

    local options = {
      onSelect = function()
        clicked = true
      end,
    }

    RowScripts.bindClick(row, item, options)
    row.scripts.OnClick(row, "RightButton")

    rawset(ContextMenu, "Open", originalOpen)

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
    rawset(ContextMenu, "Open", function()
      return false
    end)

    local options = {
      onSelect = function()
        clicked = true
      end,
    }

    RowScripts.bindClick(row, item, options)
    row.scripts.OnClick(row, "RightButton")

    rawset(ContextMenu, "Open", originalOpen)

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
  -- test_action_hover_does_not_hide_buttons_when_pointer_returns_to_row
  do
    local row = factory.CreateFrame("Button", nil, parent)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.item = {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      pinned = false,
      unreadCount = 0,
    }
    row.selected = false

    RowScripts.bindHover(row, { rowBaseBg = Theme.COLORS.bg_secondary })
    row.removeButton = ActionButtons.createRemoveButton(factory, row, 260, { onRemove = function() end })
    row.pinButton = ActionButtons.createPinButton(factory, row, row.item, 260, { onPin = function() end })

    row.mouseOver = true
    row.scripts.OnEnter(row)
    row.removeButton.mouseOver = true
    row.removeButton.scripts.OnEnter(row.removeButton)

    -- Entering a child button may trigger row OnLeave even though the pointer
    -- is still inside the row region.
    row.mouseOver = false
    row.scripts.OnLeave(row)

    -- Pointer leaves the action button and lands back on row body.
    row.removeButton.mouseOver = false
    row.mouseOver = true
    row.removeButton.scripts.OnLeave(row.removeButton)

    assert(row.removeButton:IsShown() == true, "remove button should remain visible while pointer is still over row")
    assert(row.pinButton:IsShown() == true, "pin button should remain visible while pointer is still over row")
  end

  -- test_action_hover_clears_when_pointer_leaves_row_from_button
  do
    local row = factory.CreateFrame("Button", nil, parent)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.item = {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      pinned = false,
      unreadCount = 0,
    }
    row.selected = false

    RowScripts.bindHover(row, { rowBaseBg = Theme.COLORS.bg_secondary })
    row.removeButton = ActionButtons.createRemoveButton(factory, row, 260, { onRemove = function() end })
    row.pinButton = ActionButtons.createPinButton(factory, row, row.item, 260, { onPin = function() end })

    row.mouseOver = true
    row.scripts.OnEnter(row)
    row.removeButton.mouseOver = true
    row.removeButton.scripts.OnEnter(row.removeButton)

    -- Row OnLeave can fire while entering child action button.
    row.mouseOver = false
    row.scripts.OnLeave(row)

    -- Then pointer leaves action button to outside the row entirely.
    row.removeButton.mouseOver = false
    row.mouseOver = false
    row.removeButton.scripts.OnLeave(row.removeButton)

    assert(row.removeButton:IsShown() == false, "remove button should hide when pointer leaves row")
    assert(row.pinButton:IsShown() == false, "pin button should hide when pointer leaves row")
    for i = 1, 4 do
      local actual = row.bg.color and (row.bg.color[i] or 0) or 0
      assert(math.abs(actual - 0) < 0.0001, "row background should be transparent after leaving row")
    end
  end

  -- test_hover_clears_when_action_onleave_is_missing
  do
    local row = factory.CreateFrame("Button", nil, parent)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.item = {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      pinned = false,
      unreadCount = 0,
    }
    row.selected = false

    RowScripts.bindHover(row, { rowBaseBg = Theme.COLORS.bg_secondary })
    row.removeButton = ActionButtons.createRemoveButton(factory, row, 260, { onRemove = function() end })
    row.pinButton = ActionButtons.createPinButton(factory, row, row.item, 260, { onPin = function() end })

    row.mouseOver = true
    row.scripts.OnEnter(row)
    row.removeButton.mouseOver = true
    row.removeButton.scripts.OnEnter(row.removeButton)

    -- Simulate missing button OnLeave (can happen when hovered button is hidden/rebound).
    row.removeButton.mouseOver = false
    row.mouseOver = false
    row.scripts.OnLeave(row)

    assert(row.removeButton:IsShown() == false, "remove button should hide even if action OnLeave was skipped")
    assert(row.pinButton:IsShown() == false, "pin button should hide even if action OnLeave was skipped")
    for i = 1, 4 do
      local actual = row.bg.color and (row.bg.color[i] or 0) or 0
      local expected = 0
      assert(math.abs(actual - expected) < 0.0001, "row background should clear even if action OnLeave was skipped")
    end
  end

  -- test_hover_watchdog_clears_state_when_leave_events_are_missed
  do
    local row = factory.CreateFrame("Button", nil, parent)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.item = {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      pinned = false,
      unreadCount = 0,
    }
    row.selected = false

    RowScripts.bindHover(row, { rowBaseBg = Theme.COLORS.bg_secondary })
    row.removeButton = ActionButtons.createRemoveButton(factory, row, 260, { onRemove = function() end })
    row.pinButton = ActionButtons.createPinButton(factory, row, row.item, 260, { onPin = function() end })

    row.mouseOver = true
    row.scripts.OnEnter(row)
    row.mouseOver = false
    row.removeButton.mouseOver = true
    row.removeButton.scripts.OnEnter(row.removeButton)

    -- Pointer leaves everything, but both OnLeave handlers are missed.
    row.removeButton.mouseOver = false
    row.mouseOver = false

    assert(type(row.scripts.OnUpdate) == "function", "bindHover should install OnUpdate watchdog")
    row.scripts.OnUpdate(row, 0.2)

    assert(row.removeButton:IsShown() == false, "watchdog should hide remove button when hover is stale")
    assert(row.pinButton:IsShown() == false, "watchdog should hide pin button when hover is stale")
    for i = 1, 4 do
      local actual = row.bg.color and (row.bg.color[i] or 0) or 0
      local expected = 0
      assert(math.abs(actual - expected) < 0.0001, "watchdog should restore base row background")
    end
  end

  -- test_hover_clears_after_pin_to_remove_then_leave_list
  do
    local row = factory.CreateFrame("Button", nil, parent)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.item = {
      conversationKey = "me::WOW::alice",
      displayName = "Alice",
      pinned = false,
      unreadCount = 0,
    }
    row.selected = false

    RowScripts.bindHover(row, { rowBaseBg = Theme.COLORS.bg_secondary })
    row.removeButton = ActionButtons.createRemoveButton(factory, row, 260, { onRemove = function() end })
    row.pinButton = ActionButtons.createPinButton(factory, row, row.item, 260, { onPin = function() end })

    row.mouseOver = true
    row.scripts.OnEnter(row)

    row.pinButton.mouseOver = true
    row.pinButton.scripts.OnEnter(row.pinButton)

    -- Move pin -> remove while pin OnLeave is missed (stale pin hover flag).
    row.removeButton.mouseOver = true
    row.removeButton.scripts.OnEnter(row.removeButton)

    -- Leave list from remove button: remove gets OnLeave, stale pin hover remains.
    row.removeButton.mouseOver = false
    row.mouseOver = false
    row.removeButton.scripts.OnLeave(row.removeButton)

    local previousGetMouseFocus = _G.GetMouseFocus
    _G.GetMouseFocus = function()
      return nil
    end
    row.scripts.OnUpdate(row, 0.2)
    _G.GetMouseFocus = previousGetMouseFocus

    assert(row.removeButton:IsShown() == false, "remove button should hide after leaving list from remove")
    assert(row.pinButton:IsShown() == false, "pin button should hide after leaving list from remove")
    for i = 1, 4 do
      local actual = row.bg.color and (row.bg.color[i] or 0) or 0
      local expected = 0
      assert(math.abs(actual - expected) < 0.0001, "row background should clear after pin->remove->leave")
    end
  end
end
