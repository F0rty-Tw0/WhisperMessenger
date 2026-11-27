-- The settings page clips what sticks out of its view, so a drop-down list
-- that has no room below its button opens above it, or shrinks to fit.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local DropdownSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")

local ROW = 26
local ROWS = 6

local function setRect(frame, top, bottom)
  frame.GetTop = function()
    return top
  end
  frame.GetBottom = function()
    return bottom
  end
end

-- A 10-option list on a page whose view spans viewTop..viewBottom, with its
-- button's top edge at buttonTop; opened once. viewTop nil = no page view.
-- scrollRange: how far the page can still scroll down (default 0).
local function open(viewTop, viewBottom, buttonTop, scrollRange)
  local factory = FakeUI.NewFactory()
  local root = factory.CreateFrame("Frame", "UIParent", nil)
  local parent = root
  if viewTop then
    local view = factory.CreateFrame("ScrollFrame", nil, root)
    setRect(view, viewTop, viewBottom)
    rawset(view, "GetVerticalScrollRange", function()
      return scrollRange or 0
    end)
    parent = factory.CreateFrame("Frame", nil, view)
  end
  local options = {}
  for i = 1, 10 do
    options[i] = { key = "opt" .. i, label = "Option " .. i }
  end
  local selector = DropdownSelector.Create(factory, parent, {
    labelText = "Font",
    optionsList = options,
    fallbackKey = "opt1",
    initial = "opt1",
    buttonHeight = ROW,
    menuHeight = ROWS * ROW,
  })
  setRect(selector.button, buttonTop, buttonTop - ROW)
  selector.button:GetScript("OnClick")(selector.button)
  return FindUI.dropdownMenu(selector.row), selector, parent.parent
end

local function shownRows(menu)
  local count = 0
  for _, row in ipairs(FindUI.ofType(menu.scrollChild, "Button")) do
    if row:IsShown() then
      count = count + 1
    end
  end
  return count
end

-- The menu's corner that hangs on the button.
local function corner(menu)
  return (menu:GetPoint(1))
end

return function()
  -- test_room_below_opens_below
  do
    local menu = open(600, 0, 500)
    assert(corner(menu) == "TOPLEFT", "got " .. tostring(corner(menu)))
    assert(menu:GetHeight() == ROWS * ROW, "full height, got " .. menu:GetHeight())
  end

  -- test_no_room_below_opens_above
  do
    local menu = open(600, 0, 60)
    assert(corner(menu) == "BOTTOMLEFT", "got " .. tostring(corner(menu)))
    assert(menu:GetHeight() == ROWS * ROW, "full height, got " .. menu:GetHeight())
  end

  -- test_no_room_below_scrolls_the_page_first
  -- 34 px below the button, 156 + 2 needed.
  do
    local menu, _, view = open(600, 0, 60, 400)
    assert(view:GetVerticalScroll() == 124, "scrolls what is missing, got " .. view:GetVerticalScroll())
    assert(corner(menu) == "TOPLEFT", "then it fits below, got " .. tostring(corner(menu)))
    assert(menu:GetHeight() == ROWS * ROW, "full height, got " .. menu:GetHeight())
  end

  -- test_room_below_does_not_scroll_the_page
  do
    local _, _, view = open(600, 0, 500, 400)
    assert(view:GetVerticalScroll() == 0, "got " .. view:GetVerticalScroll())
  end

  -- test_scrolling_keeps_the_button_in_view
  do
    local _, _, view = open(200, 0, 130, 400)
    assert(view:GetVerticalScroll() == 54, "156 + 2 fits below after 54 px, got " .. view:GetVerticalScroll())
    _, _, view = open(150, 0, 130, 400)
    assert(view:GetVerticalScroll() == 20, "no further than the button's top, got " .. view:GetVerticalScroll())
  end

  -- test_no_room_either_way_shrinks_to_whole_rows_that_fit
  do
    local menu = open(200, 0, 130)
    assert(corner(menu) == "TOPLEFT", "more room below, got " .. tostring(corner(menu)))
    assert(menu:GetHeight() == 3 * ROW, "102 px fit 3 rows, got " .. menu:GetHeight())
    assert(shownRows(menu) == 3, "got " .. shownRows(menu))
  end

  -- test_a_shrunk_list_is_full_height_again_where_it_fits
  do
    local menu, selector = open(200, 0, 130)
    menu:Hide()
    setRect(selector.button, 200, 174)
    selector.button:GetScript("OnClick")(selector.button)
    assert(menu:GetHeight() == ROWS * ROW, "got " .. menu:GetHeight())
    assert(shownRows(menu) == ROWS, "got " .. shownRows(menu))
  end

  -- test_no_page_view_opens_below
  do
    local menu = open(nil, nil, 10)
    assert(corner(menu) == "TOPLEFT", "got " .. tostring(corner(menu)))
  end
end
