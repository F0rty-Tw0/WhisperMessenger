-- Native rows (Native WoW HUD) mark the chosen option like WM's own menus: a
-- check mark left of a gold label, no selection bar.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local NativeArt = require("WhisperMessenger.UI.Helpers.NativeArt")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
local DropdownOptionRow = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownOptionRow")

local GOLD = { 1, 0.82, 0, 1 }
local PALETTE = {
  bg = { 0.1, 0.1, 0.1, 1 },
  bgActive = { 0.2, 0.2, 0.2, 1 },
  bgHover = { 0.3, 0.3, 0.3, 1 },
  text = { 0.4, 0.4, 0.4, 1 },
  textActive = { 0.5, 0.5, 0.5, 1 },
  textHover = { 0.6, 0.6, 0.6, 1 },
}

local function sameColor(actual, expected)
  if type(actual) ~= "table" then
    return false
  end
  for i = 1, 3 do
    if math.abs(actual[i] - expected[i]) > 1e-6 then
      return false
    end
  end
  return true
end

local function newRow(key, native)
  local factory = FakeUI.NewFactory()
  local content = factory.CreateFrame("Frame", nil, nil)
  local row = DropdownOptionRow.Create(factory, content, PALETTE, function()
    return nil
  end, function() end, native)
  row._key = key
  return row
end

local function check(row)
  return FindUI.find(row, function(n)
    return n.texturePath == PickerPopup.CHECK_TEXTURE
  end)
end

-- x offset of the label's `point` anchor (LEFT by default).
local function labelInset(row, point)
  point = point or "LEFT"
  for _, pt in ipairs(row.label.points or {}) do
    if pt[1] == point then
      return pt[4]
    end
  end
  return nil
end

local function header(row)
  row._header = true
  return row
end

return function()
  -- test_native_row_check_uses_the_menu_check_art_and_size
  do
    local mark = check(newRow("a", true))
    assert(mark and mark.width == PickerPopup.CHECK_SIZE and mark.height == PickerPopup.CHECK_SIZE, "check uses the menu's art and size")
  end

  -- test_native_row_check_sits_at_the_menu_check_inset
  do
    local mark = check(newRow("a", true))
    local left = mark and mark.points and mark.points[1]
    assert(left and left[1] == "LEFT" and left[4] == PickerPopup.CHECK_INSET, "check uses the menu's left inset")
  end

  -- test_native_row_label_does_not_wrap
  do
    assert(newRow("a", true).label.wordWrap == false, "a long choice stays on one line")
  end

  -- test_native_selected_row_shows_the_check
  do
    local row = newRow("a", true)
    DropdownOptionRow.Paint(row, PALETTE, "a")
    assert(check(row):IsShown(), "selected row shows the check")
  end

  -- test_native_unselected_row_hides_the_check
  do
    local row = newRow("a", true)
    DropdownOptionRow.Paint(row, PALETTE, "a")
    DropdownOptionRow.Paint(row, PALETTE, "b")
    assert(not check(row):IsShown(), "unselected row hides the check")
  end

  -- test_native_header_hides_the_check
  do
    local row = header(newRow("a", true))
    DropdownOptionRow.Paint(row, PALETTE, "a")
    assert(not check(row):IsShown(), "header shows no check")
  end

  -- test_native_selected_row_shows_no_bar
  do
    local row = newRow("a", true)
    DropdownOptionRow.Paint(row, PALETTE, "a")
    assert(not row.bg:IsShown() and row.bg.texturePath ~= NativeArt.LIST_SELECTED, "selected row draws no selection bar")
  end

  -- test_native_selected_text_falls_back_to_gold
  do
    local row = newRow("a", true)
    DropdownOptionRow.Paint(row, PALETTE, "a")
    assert(sameColor(row.label.textColor, GOLD), "selected text is the game's gold")
  end

  -- test_native_selected_text_uses_normal_font_color
  do
    local saved = _G.NORMAL_FONT_COLOR
    _G.NORMAL_FONT_COLOR = { r = 0.9, g = 0.7, b = 0.1 }
    local row = newRow("a", true)
    DropdownOptionRow.Paint(row, PALETTE, "a")
    _G.NORMAL_FONT_COLOR = saved
    assert(sameColor(row.label.textColor, { 0.9, 0.7, 0.1 }), "selected text follows NORMAL_FONT_COLOR")
  end

  -- test_native_unselected_text_keeps_the_palette_colour
  do
    local row = newRow("a", true)
    DropdownOptionRow.Paint(row, PALETTE, "b")
    assert(sameColor(row.label.textColor, PALETTE.text), "unselected text is palette.text")
  end

  -- test_native_choice_label_leaves_room_for_the_check
  do
    local row = newRow("a", true)
    DropdownOptionRow.Paint(row, PALETTE, "b")
    assert(labelInset(row) == PickerPopup.CHECK_LABEL_PAD, "choice label starts after the check, got " .. tostring(labelInset(row)))
  end

  -- test_native_choice_label_keeps_its_right_inset
  do
    local row = newRow("a", true)
    DropdownOptionRow.Paint(row, PALETTE, "b")
    assert(labelInset(row, "RIGHT") == -8, "choice label stops 8px short of the right edge, got " .. tostring(labelInset(row, "RIGHT")))
  end

  -- test_native_header_label_starts_at_the_edge
  do
    local row = header(newRow("a", true))
    DropdownOptionRow.Paint(row, PALETTE, "b")
    assert(labelInset(row) == 8, "header label keeps the plain inset, got " .. tostring(labelInset(row)))
  end

  -- test_native_pooled_header_turned_choice_moves_its_label_back
  do
    local row = header(newRow("a", true))
    DropdownOptionRow.Paint(row, PALETTE, "b")
    row._header = nil
    DropdownOptionRow.Paint(row, PALETTE, "b")
    assert(labelInset(row) == PickerPopup.CHECK_LABEL_PAD, "a pooled header that becomes a choice lines up again")
  end

  -- test_native_header_text_uses_the_secondary_colour
  do
    local row = header(newRow("a", true))
    DropdownOptionRow.Paint(row, PALETTE, "a")
    assert(sameColor(row.label.textColor, Theme.COLORS.text_secondary), "header text is text_secondary")
  end

  -- test_modern_row_has_no_check
  do
    local row = newRow("a", false)
    DropdownOptionRow.Paint(row, PALETTE, "a")
    assert(check(row) == nil, "modern row has no check")
  end

  -- test_modern_label_keeps_its_inset
  do
    local row = newRow("a", false)
    assert(labelInset(row) == 8 and labelInset(row, "RIGHT") == -8, "modern label insets unchanged")
  end
end
