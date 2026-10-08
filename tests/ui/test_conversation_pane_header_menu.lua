local FakeUI = require("tests.helpers.fake_ui")
local HeaderMenu = require("WhisperMessenger.UI.ConversationPane.HeaderMenu")

-- window -> pane -> header, the way the conversation header hangs under the
-- messenger window (with frames in between that have no window scripts).
local function buildChain(factory)
  local window = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, window)
  local header = factory.CreateFrame("Frame", nil, pane)
  return window, pane, header
end

local function spyMenu()
  local calls = {}
  local cm = {
    Open = function(...)
      calls[#calls + 1] = { n = select("#", ...), ... }
      return true
    end,
  }
  return cm, calls
end

local function fire(frame, eventName, ...)
  local handler = frame:GetScript(eventName)
  assert(type(handler) == "function", "header should have an " .. eventName .. " script")
  handler(frame, ...)
end

return function()
  local factory = FakeUI.NewFactory()

  -- test_right_click_opens_menu_for_selected_contact
  do
    local _, _, header = buildChain(factory)
    local contact = { displayName = "Arthas", channel = "WOW" }
    local opts = { onMarkUnread = function() end, onUpdatePrefs = function() end }
    local cm, calls = spyMenu()
    HeaderMenu.Bind(header, { _selectedContact = contact }, opts, cm)

    fire(header, "OnMouseUp", "RightButton")
    assert(#calls == 1, "right-click should open the menu once, got " .. #calls)
    local call = calls[1]
    assert(call[1] == contact, "menu should target the selected contact")
    assert(call[2] == header, "menu should anchor to the header")
    assert(call[3] == opts.onMarkUnread, "menu should get onMarkUnread")
    assert(call[4] == opts.onUpdatePrefs, "menu should get onUpdatePrefs")
    assert(call.n == 4, "menu should get no row actions, got " .. call.n .. " args")
  end

  -- test_right_click_on_group_conversation_opens_menu
  do
    local _, _, header = buildChain(factory)
    local group = { displayName = "Guild", channel = "GUILD" }
    local cm, calls = spyMenu()
    HeaderMenu.Bind(header, { _selectedContact = group }, {}, cm)

    fire(header, "OnMouseUp", "RightButton")
    assert(#calls == 1 and calls[1][1] == group, "right-click on a group header should open its menu")
  end

  -- test_right_click_targets_contact_selected_after_bind
  do
    local _, _, header = buildChain(factory)
    local view = { _selectedContact = { displayName = "Arthas", channel = "WOW" } }
    local cm, calls = spyMenu()
    HeaderMenu.Bind(header, view, {}, cm)
    local other = { displayName = "Jaina", channel = "BN" }
    view._selectedContact = other

    fire(header, "OnMouseUp", "RightButton")
    assert(#calls == 1 and calls[1][1] == other, "menu should target the contact selected at click time")
  end

  -- test_left_mouse_up_opens_no_menu
  do
    local _, _, header = buildChain(factory)
    local cm, calls = spyMenu()
    HeaderMenu.Bind(header, { _selectedContact = { displayName = "Arthas", channel = "WOW" } }, {}, cm)

    fire(header, "OnMouseUp", "LeftButton")
    assert(#calls == 0, "left-click should not open the menu")
  end

  -- test_right_click_without_contact_opens_no_menu
  do
    local _, _, header = buildChain(factory)
    local cm, calls = spyMenu()
    HeaderMenu.Bind(header, { _selectedContact = nil }, {}, cm)

    fire(header, "OnMouseUp", "RightButton")
    assert(#calls == 0, "right-click with no conversation should not open a menu")
  end

  -- test_drag_moves_and_saves_through_window
  do
    local window, _, header = buildChain(factory)
    window:SetScript("OnDragStart", function(self)
      self:StartMoving()
    end)
    window:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
    end)
    HeaderMenu.Bind(header, {}, {}, spyMenu())

    assert(header.dragButtons ~= nil and header.dragButtons[1] == "LeftButton", "header should register a left-button drag")
    fire(header, "OnDragStart")
    fire(header, "OnDragStop")
    assert(window.startedMoving == true, "dragging the header should move the window")
    assert(window.stoppedMoving == true, "releasing the drag should stop moving the window")
    assert(header.startedMoving ~= true, "the header itself should not move")
  end

  -- test_mouse_down_raises_window
  do
    local window, _, header = buildChain(factory)
    local seen = nil
    window:SetScript("OnMouseDown", function(self, button)
      seen = { self, button }
    end)
    HeaderMenu.Bind(header, {}, {}, spyMenu())

    fire(header, "OnMouseDown", "RightButton")
    assert(seen ~= nil, "a click on the header should reach the window's OnMouseDown")
    assert(seen[1] == window, "the window's OnMouseDown should get the window as self")
    assert(seen[2] == "RightButton", "the window's OnMouseDown should get the button")
  end

  -- test_window_scripts_set_after_bind_are_reached
  do
    local window, _, header = buildChain(factory)
    HeaderMenu.Bind(header, {}, {}, spyMenu())
    local reached = false
    window:SetScript("OnMouseDown", function()
      reached = true
    end)

    fire(header, "OnMouseDown", "LeftButton")
    assert(reached, "window scripts bound after the header should still be reached")
  end

  -- test_no_scripted_ancestor_is_a_no_op
  do
    local header = factory.CreateFrame("Frame", nil, nil)
    HeaderMenu.Bind(header, {}, {}, spyMenu())

    fire(header, "OnMouseDown", "LeftButton")
    fire(header, "OnDragStart")
    fire(header, "OnDragStop")
  end

  -- test_header_accepts_mouse
  do
    local _, _, header = buildChain(factory)
    HeaderMenu.Bind(header, {}, {}, spyMenu())
    assert(header.mouseEnabled == true, "header should accept mouse input")
  end
end
