local FakeUI = require("tests.helpers.fake_ui")
local HeaderMenu = require("WhisperMessenger.UI.ConversationPane.HeaderMenu")

local function buildChain(factory)
  local window = factory.CreateFrame("Frame", nil, nil)
  local pane = factory.CreateFrame("Frame", nil, window)
  local header = factory.CreateFrame("Frame", nil, pane)
  return window, header
end

local function fire(frame, eventName, ...)
  local handler = frame:GetScript(eventName)
  assert(type(handler) == "function", "header should have an " .. eventName .. " script")
  handler(frame, ...)
end

local function spyMenu()
  local calls = {}
  return {
    Open = function(...)
      calls[#calls + 1] = { ... }
    end,
  }, calls
end

-- Binds a header whose name is under (or not under) the mouse. Returns the
-- window, the header, the whoPlayer names, the menu calls, the keys passed to
-- onHeaderClicked and the view.
local function setup(factory, contact, overName, withWho)
  local window, header = buildChain(factory)
  local nameText = factory.CreateFrame("Frame", nil, header)
  nameText.mouseOver = overName
  local view = { headerName = nameText, _selectedContact = contact, _selectedConversationKey = "wow::jaina" }
  local whoNames = {}
  local headerClicks = {}
  local options = {
    onHeaderClicked = function(conversationKey)
      headerClicks[#headerClicks + 1] = conversationKey
    end,
  }
  if withWho ~= false then
    options.whoPlayer = function(name)
      whoNames[#whoNames + 1] = name
      return true
    end
  end
  local menu, menuCalls = spyMenu()
  HeaderMenu.Bind(header, view, options, menu)
  return window, header, whoNames, menuCalls, headerClicks, view
end

return function()
  local factory = FakeUI.NewFactory()
  local wowContact = { displayName = "Bob", channel = "WOW" }
  local originalShift = _G.IsShiftKeyDown
  local function withShift(isDown, fn)
    _G.IsShiftKeyDown = function()
      return isDown
    end
    local ok, err = pcall(fn)
    _G.IsShiftKeyDown = originalShift
    assert(ok, tostring(err))
  end

  -- test_shift_left_click_over_name_sends_who
  withShift(true, function()
    local _, header, whoNames = setup(factory, wowContact, true)
    fire(header, "OnMouseUp", "LeftButton")
    assert(#whoNames == 1 and whoNames[1] == "Bob", "shift-click on the name should /who the contact")
  end)

  -- test_click_without_shift_sends_no_who
  withShift(false, function()
    local _, header, whoNames = setup(factory, wowContact, true)
    fire(header, "OnMouseUp", "LeftButton")
    assert(#whoNames == 0, "plain click should not /who")
  end)

  -- test_click_off_the_name_sends_no_who
  withShift(true, function()
    local _, header, whoNames = setup(factory, wowContact, false)
    fire(header, "OnMouseUp", "LeftButton")
    assert(#whoNames == 0, "shift-click off the name should not /who")
  end)

  -- test_drag_then_release_sends_no_who_but_next_click_does
  withShift(true, function()
    local _, header, whoNames = setup(factory, wowContact, true)
    fire(header, "OnMouseDown", "LeftButton")
    fire(header, "OnDragStart")
    fire(header, "OnMouseUp", "LeftButton")
    assert(#whoNames == 0, "releasing after a window drag should not /who")
    fire(header, "OnMouseDown", "LeftButton")
    fire(header, "OnMouseUp", "LeftButton")
    assert(#whoNames == 1, "a fresh click after a drag should /who")
  end)

  -- test_drag_and_mouse_down_still_forward_to_window
  do
    local window, header = setup(factory, wowContact, true)
    local seen = {}
    window:SetScript("OnMouseDown", function(_self, button)
      seen.down = button
    end)
    window:SetScript("OnDragStart", function()
      seen.drag = true
    end)
    fire(header, "OnMouseDown", "LeftButton")
    fire(header, "OnDragStart")
    assert(seen.down == "LeftButton" and seen.drag == true, "forwarders should still reach the window")
  end

  -- test_bn_contact_sends_no_who
  withShift(true, function()
    local _, header, whoNames = setup(factory, { displayName = "Bob", channel = "BN" }, true)
    fire(header, "OnMouseUp", "LeftButton")
    assert(#whoNames == 0, "BN chats should not /who")
  end)

  -- test_right_click_still_opens_menu
  withShift(true, function()
    local _, header, whoNames, menuCalls = setup(factory, wowContact, true)
    fire(header, "OnMouseUp", "RightButton")
    assert(#menuCalls == 1 and #whoNames == 0, "right-click should open the menu, not /who")
  end)

  -- test_plain_left_click_asks_quiet_who
  withShift(false, function()
    local _, header, _, _, headerClicks = setup(factory, wowContact, true)
    fire(header, "OnMouseUp", "LeftButton")
    assert(#headerClicks == 1 and headerClicks[1] == "wow::jaina", "plain left-click should ask for the shown chat")
  end)

  -- test_plain_left_click_off_the_name_asks_quiet_who
  withShift(false, function()
    local _, header, _, _, headerClicks = setup(factory, wowContact, false)
    fire(header, "OnMouseUp", "LeftButton")
    assert(#headerClicks == 1, "the whole header takes the click, not only the name")
  end)

  -- test_shift_click_on_name_sends_only_visible_who
  withShift(true, function()
    local _, header, whoNames, _, headerClicks = setup(factory, wowContact, true)
    fire(header, "OnMouseUp", "LeftButton")
    assert(#whoNames == 1 and #headerClicks == 0, "shift-click on the name is the visible /who only")
  end)

  -- test_drag_then_mouse_up_asks_nothing
  withShift(false, function()
    local _, header, _, _, headerClicks = setup(factory, wowContact, true)
    fire(header, "OnMouseDown", "LeftButton")
    fire(header, "OnDragStart")
    fire(header, "OnMouseUp", "LeftButton")
    assert(#headerClicks == 0, "releasing after a window drag should not ask")
    fire(header, "OnMouseDown", "LeftButton")
    fire(header, "OnMouseUp", "LeftButton")
    assert(#headerClicks == 1, "a fresh click after a drag should ask")
  end)

  -- test_right_click_opens_menu_without_asking
  withShift(false, function()
    local _, header, _, menuCalls, headerClicks = setup(factory, wowContact, true)
    fire(header, "OnMouseUp", "RightButton")
    assert(#menuCalls == 1 and #headerClicks == 0, "right-click opens the menu and asks nothing")
  end)

  -- test_no_selected_chat_asks_nothing
  withShift(false, function()
    local _, header, _, _, headerClicks, view = setup(factory, wowContact, true)
    view._selectedConversationKey = nil
    fire(header, "OnMouseUp", "LeftButton")
    assert(#headerClicks == 0, "no shown chat, nothing to ask for")
  end)

  -- test_missing_header_click_callback_is_a_no_op
  withShift(false, function()
    local _, header, _, _, _, view = setup(factory, wowContact, true)
    view._selectedConversationKey = "wow::jaina"
    HeaderMenu.Bind(header, view, {}, nil)
    fire(header, "OnMouseUp", "LeftButton")
  end)

  -- test_missing_who_callback_is_a_no_op
  withShift(true, function()
    local _, header = setup(factory, wowContact, true, false)
    fire(header, "OnMouseUp", "LeftButton")
  end)
end
