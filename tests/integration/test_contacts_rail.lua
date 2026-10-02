local MessengerWindow = require("WhisperMessenger.UI.MessengerWindow")
local ContactsList = require("WhisperMessenger.UI.ContactsList")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local L = Theme.LAYOUT
local RAIL = L.CONTACTS_RAIL_WIDTH
local COLLAPSED_MIN = RAIL + Theme.DIVIDER_THICKNESS + L.CONTENT_MIN_WIDTH
local EXPANDED_FIT = 300 + Theme.DIVIDER_THICKNESS + L.CONTENT_MIN_WIDTH

-- The collapsed contacts rail, end to end: snapping by dragging the divider,
-- the saved flag, the magnifier, settings width and growing a narrow window.

local function contacts()
  return ContactsList.BuildItems({
    ["me::WOW::jaina"] = { displayName = "Jaina", channel = "WOW", lastActivityAt = 2, unreadCount = 1 },
    ["guild::me"] = { displayName = "Guild", channel = "GUILD", lastActivityAt = 1, unreadCount = 0 },
  })
end

local function build(state, hudStyle)
  Hud.Configure(hudStyle or "off")
  local factory = FakeUI.NewFactory()
  local savedUIParent = _G.UIParent
  _G.UIParent = factory.CreateFrame("Frame", "UIParent", nil)
  _G.UIParent:SetSize(1920, 1080)
  local saved = {}
  local window = MessengerWindow.Create(factory, {
    contacts = contacts(),
    state = state,
    settingsConfig = { showGroupChats = true },
    onPositionChanged = function(nextState)
      saved.state = nextState
    end,
  })
  rawset(window.frame, "GetEffectiveScale", function()
    return 1
  end)
  Hud.Configure("off")
  _G.UIParent = savedUIParent
  return window, saved
end

local function setLeft(window, left)
  rawset(window.frame, "GetLeft", function()
    return left
  end)
  rawset(window.frame, "GetTop", function()
    return 800
  end)
end

-- Press on the divider at the first x, move through the rest frame by
-- frame (window-relative, window left at 0), release at the last.
local function dragPath(window, xs, onStep)
  local cursorX = xs[1]
  rawset(_G, "GetCursorPosition", function()
    return cursorX, 0
  end)
  local handle = window.contactsResizeHandle
  handle.scripts.OnMouseDown(handle, "LeftButton")
  for index = 2, #xs do
    cursorX = xs[index]
    window.frame.scripts.OnUpdate(window.frame, 0)
    if onStep then
      onStep(xs[index])
    end
  end
  handle.scripts.OnMouseUp(handle, "LeftButton")
end

local function assertCollapsedLook(window, label)
  assert(window.contactsPane.width == RAIL, label .. ": pane is rail wide, got " .. tostring(window.contactsPane.width))
  assert(window.contacts.rows[1]._wmCompact == true, label .. ": rows are icon-only")
  assert(window.contactsRailSearchButton.shown == true, label .. ": magnifier shows")
  assert(window.contactsSearchInput:GetParent().shown == false, label .. ": search field hides")
  assert(window.contacts.view.barHidden == true, label .. ": no scrollbar in the rail")
end

return function()
  local savedCursor = _G.GetCursorPosition

  -- test_saved_collapsed_state_opens_as_the_rail
  do
    local window = build({ width = COLLAPSED_MIN, height = 500, contactsWidth = 300, contactsCollapsed = true })
    assertCollapsedLook(window, "reload")
    assert(window.frame.width == COLLAPSED_MIN, "narrow collapsed window survives a reload, got " .. tostring(window.frame.width))
    assert(window.frame:GetResizeBounds() == COLLAPSED_MIN, "resize minimum drops while collapsed")
    local _, relativeTo = table.unpack(window.tabToggle.frame.points[1])
    assert(relativeTo == window.frame, "modern tabs hang below the window")
  end

  -- test_dragging_the_divider_far_left_snaps_to_the_rail_and_saves_it_on_release
  do
    local window, saved = build({ width = 900, height = 560, contactsWidth = 300 })
    setLeft(window, 0)
    dragPath(window, { 300, 200, 150, 100, 50 }, function(x)
      if x == 50 then
        assert(saved.state == nil, "nothing is saved mid-drag")
      end
    end)
    assertCollapsedLook(window, "snap")
    assert(saved.state.contactsCollapsed == true, "collapsed flag saved on release")
  end

  -- test_rail_edge_drag_out_follows_the_pointer
  do
    local window, saved = build({ width = 900, height = 560, contactsWidth = 260, contactsCollapsed = true })
    setLeft(window, 0)
    dragPath(window, { RAIL, 80, 140, 220 })
    assert(window.contactsPane.width == 220, "pane follows the pointer out, got " .. tostring(window.contactsPane.width))
    assert(window.contacts.rows[1]._wmCompact == false, "rows show full again")
    assert(window.contactsRailSearchButton.shown == false, "magnifier hides")
    assert(saved.state.contactsCollapsed == false and saved.state.contactsWidth == 220, "expanded state saved on release")
  end

  -- test_one_drag_goes_rail_and_back_any_number_of_times
  do
    local window, saved = build({ width = 900, height = 560, contactsWidth = 300 })
    setLeft(window, 0)
    local seen = {}
    dragPath(window, { 300, 60, 250, 40, 230, 30 }, function(x)
      seen[#seen + 1] = window.contactsPane.width
      assert(window.contacts.rows[1]._wmCompact == (x < 100), "rows follow the pane at x=" .. x)
    end)
    assert(seen[1] == RAIL and seen[2] == 250 and seen[3] == RAIL and seen[4] == 230 and seen[5] == RAIL, "rail, 250, rail, 230, rail")
    assert(saved.state.contactsCollapsed == true, "final state saved")
  end

  -- test_unsnap_without_resize_bounds_api_does_not_error
  do
    local window = build({ width = 900, height = 560, contactsWidth = 300, contactsCollapsed = true })
    setLeft(window, 0)
    rawset(window.frame, "GetResizeBounds", nil)
    dragPath(window, { RAIL, 200 })
    assert(window.contactsPane.width == 200, "un-snaps on clients without GetResizeBounds, got " .. tostring(window.contactsPane.width))
  end

  -- test_divider_handle_sits_above_the_rail_and_chat
  do
    local window = build({ width = 900, height = 560, contactsWidth = 300, contactsCollapsed = true })
    local handleLevel = window.contactsResizeHandle:GetFrameLevel()
    local paneLevel = window.contactsPane:GetFrameLevel()
    assert(handleLevel >= paneLevel + L.CONTACTS_RESIZE_HANDLE_LEVEL_LIFT, "handle lifted over the pane's rows and the chat edge")
  end

  -- test_magnifier_expands_and_focuses_search
  do
    local window, saved = build({ width = 900, height = 560, contactsWidth = 300, contactsCollapsed = true })
    window.contactsRailSearchButton.scripts.OnClick(window.contactsRailSearchButton)
    assert(window.contactsPane.width == 300, "magnifier un-snaps to the expanded width")
    assert(window.contactsSearchInput:HasFocus() == true, "search box gets focus")
    assert(saved.state.contactsCollapsed == false, "expanded flag saved")
  end

  -- test_unsnap_grows_a_narrow_window_keeping_its_left_edge
  do
    local window = build({ width = COLLAPSED_MIN, height = 500, contactsWidth = 300, contactsCollapsed = true })
    setLeft(window, 100)
    window.contactsRailSearchButton.scripts.OnClick(window.contactsRailSearchButton)
    assert(window.frame.width == EXPANDED_FIT, "window grows to fit the pane, got " .. tostring(window.frame.width))
    local point, _, _, x = window.frame:GetPoint()
    assert(point == "TOPLEFT" and x == 100, "left edge kept, got " .. tostring(x))
    assert(window.contactsPane.width == 300, "pane back at its width")
  end

  -- test_unsnap_near_the_right_screen_edge_stays_on_screen
  do
    local window = build({ width = COLLAPSED_MIN, height = 500, contactsWidth = 300, contactsCollapsed = true })
    setLeft(window, 1800)
    window.contactsRailSearchButton.scripts.OnClick(window.contactsRailSearchButton)
    local _, _, _, x = window.frame:GetPoint()
    assert(x == 1920 - EXPANDED_FIT, "window shifts left to stay on screen, got " .. tostring(x))
  end

  -- test_settings_nav_keeps_the_expanded_width_while_collapsed
  do
    local window = build({ width = 900, height = 560, contactsWidth = 300, contactsCollapsed = true })
    assert(window.optionsMenu.width == 300, "settings nav readable, got " .. tostring(window.optionsMenu.width))
    window.optionsButton.scripts.OnClick(window.optionsButton)
    window.backButton.scripts.OnClick(window.backButton)
    assertCollapsedLook(window, "after settings")
  end

  -- test_native_hud_rail_keeps_its_native_tabs
  do
    local window = build({ width = 900, height = 560, contactsWidth = 300, contactsCollapsed = true }, "classic")
    assert(window.contactsPane.width == RAIL, "HUD pane is rail wide")
    assert(window.contacts.rows[1]._wmCompact == true, "HUD rows are icon-only")
    assert(window.tabToggle.setHanging == nil, "HUD keeps its own hanging tabs")
  end

  rawset(_G, "GetCursorPosition", savedCursor)
end
