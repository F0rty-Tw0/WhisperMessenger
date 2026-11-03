local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local DropdownOptionRow = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownOptionRow")

local PALETTE = {
  bg = { 0.1, 0.1, 0.1, 1 },
  bgActive = { 0.2, 0.2, 0.2, 1 },
  bgHover = { 0.3, 0.3, 0.3, 1 },
  text = { 0.4, 0.4, 0.4, 1 },
  textActive = { 0.5, 0.5, 0.5, 1 },
  textHover = { 0.6, 0.6, 0.6, 1 },
}

local function colorsMatch(a, b)
  return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and (a[4] or 1) == (b[4] or 1)
end

local function newRow(key, selection, picks)
  local factory = FakeUI.NewFactory()
  local content = factory.CreateFrame("Frame", nil, nil)
  local row = DropdownOptionRow.Create(factory, content, PALETTE, function()
    return selection.key
  end, function(picked)
    picks[#picks + 1] = picked
  end)
  row._key = key
  return row
end

local function painted(row, bg, text)
  return colorsMatch(row.bg.color, bg) and colorsMatch(row.label.textColor, text)
end

return function()
  -- test_option_row_paints_rest_selected_and_hover_states
  do
    local row = newRow("a", { key = "b" }, {})
    DropdownOptionRow.Paint(row, PALETTE, "b")
    assert(painted(row, PALETTE.bg, PALETTE.text), "unselected row rests")
    DropdownOptionRow.Paint(row, PALETTE, "a")
    assert(painted(row, PALETTE.bgActive, PALETTE.textActive), "selected row is active")
    row._hovered = true
    DropdownOptionRow.Paint(row, PALETTE, "a")
    assert(painted(row, PALETTE.bgActive, PALETTE.textActive), "selection wins over hover")
  end

  -- test_option_row_header_ignores_selection_and_hover
  do
    local row = newRow("a", { key = "a" }, {})
    row._header = true
    row._hovered = true
    DropdownOptionRow.Paint(row, PALETTE, "a")
    assert(painted(row, PALETTE.bg, Theme.COLORS.text_secondary), "header stays flat with secondary text")
  end

  -- test_option_row_hover_reads_the_live_selection
  do
    local selection = { key = "other" }
    local row = newRow("a", selection, {})
    row.scripts.OnEnter(row)
    assert(row._hovered and painted(row, PALETTE.bgHover, PALETTE.textHover), "hover paints the hover wash")
    selection.key = "a"
    row.scripts.OnLeave(row)
    assert(not row._hovered and painted(row, PALETTE.bgActive, PALETTE.textActive), "leave paints the selection made meanwhile")
  end

  -- test_option_row_click_picks_choices_not_headers
  do
    local picks = {}
    local row = newRow("a", { key = nil }, picks)
    FindUI.click(row)
    assert(#picks == 1 and picks[1] == "a", "click picks the row key")
    row._header = true
    FindUI.click(row)
    assert(#picks == 1, "click on a header picks nothing")
  end

  -- test_option_row_repaint_all_paints_every_row
  do
    local first = newRow("a", {}, {})
    local second = newRow("b", {}, {})
    DropdownOptionRow.RepaintAll({ first, second }, PALETTE, "b")
    assert(painted(first, PALETTE.bg, PALETTE.text) and painted(second, PALETTE.bgActive, PALETTE.textActive), "each row repainted")
  end
end
