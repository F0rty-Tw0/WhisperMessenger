-- WhisperMessenger's own dropdown list does not clip its rows: on WoW:
-- Forever a clipping scroll frame inside the settings page's clipping scroll
-- frame draws none of its children. The list shows only the rows that sit
-- inside the scrolled view and hides the rest.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local DropdownSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")

local ROW = 26
local VISIBLE_ROWS = 3

local function optionList(count)
  local list = {}
  for i = 1, count do
    list[i] = { key = "opt" .. i, label = "Option " .. i }
  end
  return list
end

-- Every pooled row button of the list, in creation order, shown or not.
local function pooledRows(selector)
  local menu = FindUI.dropdownMenu(selector.row)
  return FindUI.ofType(menu.scrollChild, "Button")
end

-- Indices of the pooled rows that are shown, joined for messages.
local function shownIndices(selector)
  local shown = {}
  for i, button in ipairs(pooledRows(selector)) do
    if button:IsShown() then
      shown[#shown + 1] = tostring(i)
    end
  end
  return table.concat(shown, ",")
end

local function build(factory, parent, options)
  local selector = DropdownSelector.Create(factory, parent, {
    labelText = "Mention sound",
    optionsList = options.optionsList,
    getOptions = options.getOptions,
    fallbackKey = "opt1",
    initial = options.initial or "opt1",
    buttonHeight = ROW,
    menuHeight = VISIBLE_ROWS * ROW,
  })
  return selector, FindUI.dropdownMenu(selector.row)
end

local function open(selector)
  selector.button:GetScript("OnClick")(selector.button)
end

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)

  -- test_menu_does_not_clip_its_rows
  do
    local selector, menu = build(factory, parent, { optionsList = optionList(10) })
    open(selector)
    assert(menu.clipsChildren ~= true, "test_menu_does_not_clip_its_rows: the list must not clip its rows")
  end

  -- test_open_shows_only_rows_inside_the_view
  do
    local selector = build(factory, parent, { optionsList = optionList(10) })
    open(selector)
    local shown = shownIndices(selector)
    assert(shown == "1,2,3", "test_open_shows_only_rows_inside_the_view: got " .. shown)
  end

  -- test_wheel_down_one_step_shows_the_next_row_and_hides_the_first
  do
    local selector, menu = build(factory, parent, { optionsList = optionList(10) })
    open(selector)
    menu:GetScript("OnMouseWheel")(menu, -1)
    assert(menu:GetVerticalScroll() == ROW, "test_wheel_down: one step scrolls one row, got " .. menu:GetVerticalScroll())
    local shown = shownIndices(selector)
    assert(shown == "2,3,4", "test_wheel_down: got " .. shown)
  end

  -- test_open_scrolled_to_a_selection_below_the_first_page_shows_it
  do
    local selector, menu = build(factory, parent, { optionsList = optionList(10), initial = "opt8" })
    open(selector)
    assert(menu:GetVerticalScroll() == 7 * ROW, "test_scroll_to_selected: offset is whole rows, got " .. menu:GetVerticalScroll())
    local shown = shownIndices(selector)
    assert(shown == "8,9,10", "test_scroll_to_selected: got " .. shown)
  end

  -- test_pooled_rows_past_the_list_stay_hidden_and_scrolled_rows_come_back
  do
    local source = optionList(10)
    local selector, menu = build(factory, parent, {
      getOptions = function()
        return source
      end,
    })
    open(selector)
    menu:Hide()
    source = optionList(4)
    open(selector)
    local wheel = menu:GetScript("OnMouseWheel")
    wheel(menu, -1)
    local shown = shownIndices(selector)
    assert(#pooledRows(selector) == 10, "test_pooled_rows: the pool keeps the longer list's rows")
    assert(shown == "2,3,4", "test_pooled_rows: rows past the list stay hidden, got " .. shown)
    wheel(menu, 1)
    shown = shownIndices(selector)
    assert(shown == "1,2,3", "test_pooled_rows: a row scrolled back into view shows again, got " .. shown)
  end

  print("  All dropdown selector window tests passed")
end
