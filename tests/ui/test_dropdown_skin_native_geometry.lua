-- Under the Native look the open list is a tooltip panel, so its rows (and
-- their hover / selected art) sit inside the panel's border instead of on
-- it. The modern list keeps its edge-to-edge rows.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Flavor = require("tests.helpers.flavor")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local DropdownSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")

local ROW_WIDTH = 280
local ROW_HEIGHT = 26
local MENU_HEIGHT = 156
local INSET = Theme.LAYOUT.NATIVE_BORDER_INSET

local function optionList(count)
  local list = {}
  for i = 1, count do
    list[i] = { key = "font" .. i, label = "Font " .. i }
  end
  return list
end

-- Font dropdown of `count` options with `initial` selected; `native` builds
-- it on Forever under the Native look (switched off right after Create).
-- `menuHeight` defaults to MENU_HEIGHT.
local function build(native, count, initial, menuHeight)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local dropdown
  local function create()
    dropdown = DropdownSelector.Create(factory, parent, {
      labelText = "Font Family",
      optionsList = optionList(count),
      fallbackKey = "font1",
      initial = initial or "font1",
      rowWidth = ROW_WIDTH,
      buttonHeight = ROW_HEIGHT,
      menuHeight = menuHeight or MENU_HEIGHT,
    })
  end
  if not native then
    create()
    return dropdown
  end
  Flavor.With(true, true, function()
    Hud.Configure("classic")
    local ok, err = pcall(create)
    Hud.Configure("off")
    if not ok then
      error(err, 0)
    end
  end)
  return dropdown
end

-- Each row's box in the scroll child's space (y grows downwards), walking
-- the anchor chain: the first row hangs off the content, the rest off the
-- row above.
local function rowBoxes(rows)
  local boxes = {}
  for i, row in ipairs(rows) do
    local point, _, relativePoint, x, y = row:GetPoint()
    assert(point == "TOPLEFT", "row " .. i .. " anchors by TOPLEFT")
    local left, top
    if i == 1 then
      assert(relativePoint == "TOPLEFT", "first row hangs off the content's TOPLEFT")
      left, top = x, 0 - y
    else
      assert(relativePoint == "BOTTOMLEFT", "row " .. i .. " stacks under the row above")
      left, top = boxes[i - 1].left + x, boxes[i - 1].bottom - y
    end
    boxes[i] = { left = left, top = top, right = left + row:GetWidth(), bottom = top + row:GetHeight() }
  end
  return boxes
end

local function assertInsidePanel(menu, rows)
  local width, height = menu:GetWidth(), menu:GetHeight()
  for i, box in ipairs(rowBoxes(rows)) do
    local where = string.format("row %d at %s,%s..%s,%s in a %sx%s panel", i, box.left, box.top, box.right, box.bottom, width, height)
    assert(box.left >= INSET and box.right <= width - INSET, where .. ": clears the left and right border")
    assert(box.top >= INSET, where .. ": clears the top border")
    assert(box.bottom <= height - INSET, where .. ": clears the bottom border")
  end
end

return function()
  -- test_native_panel_covers_the_menu
  do
    local menu = FindUI.dropdownMenu(build(true, 3).row)
    local panel = assert(
      FindUI.find(menu, function(n)
        return n.template == "TooltipBackdropTemplate"
      end),
      "tooltip panel is drawn"
    )
    assert(panel.allPoints == menu, "tooltip panel spans the menu")
  end

  -- test_native_rows_sit_inside_the_panel_border
  do
    local dd = build(true, 3)
    assertInsidePanel(FindUI.dropdownMenu(dd.row), FindUI.dropdownOptions(dd.row))
  end

  -- test_native_menu_keeps_the_button_width
  do
    local dd = build(true, 3)
    assert(FindUI.dropdownMenu(dd.row):GetWidth() == ROW_WIDTH, "native menu stays as wide as the button")
  end

  -- test_native_scrolled_to_the_end_last_row_sits_inside_the_border
  do
    local dd = build(true, 40)
    local menu = FindUI.dropdownMenu(dd.row)
    local rows = FindUI.dropdownOptions(dd.row)
    menu:SetVerticalScroll(menu:GetVerticalScrollRange())
    local last = rowBoxes(rows)[#rows]
    local bottom = last.bottom - menu:GetVerticalScroll()
    assert(bottom <= menu:GetHeight() - INSET, "last row clears the bottom border at full scroll, bottom " .. bottom)
  end

  -- test_native_menu_shows_the_same_number_of_rows
  do
    local menu = FindUI.dropdownMenu(build(true, 40).row)
    assert(menu:GetHeight() - 2 * INSET == MENU_HEIGHT, "native list area is menuHeight tall, menu " .. menu:GetHeight())
  end

  -- test_native_scroll_range_is_unchanged
  do
    local native = FindUI.dropdownMenu(build(true, 40).row)
    local modern = FindUI.dropdownMenu(build(false, 40).row)
    assert(native:GetVerticalScrollRange() == modern:GetVerticalScrollRange(), "native scroll range matches the modern one")
  end

  -- test_native_open_scrolls_the_selected_row_inside_the_border
  do
    -- Row 6 ends at 156: past a 150 list area, though inside the 158 menu.
    local dd = build(true, 40, "font6", 150)
    local menu = FindUI.dropdownMenu(dd.row)
    FindUI.click(dd.button)
    local box = rowBoxes(FindUI.dropdownOptions(dd.row))[6]
    local offset = menu:GetVerticalScroll()
    assert(box.top - offset >= INSET and box.bottom - offset <= menu:GetHeight() - INSET, "selected row inside the border, offset " .. offset)
  end

  -- test_modern_rows_fill_the_menu_edge_to_edge
  do
    local dd = build(false, 3)
    local menu = FindUI.dropdownMenu(dd.row)
    local boxes = rowBoxes(FindUI.dropdownOptions(dd.row))
    assert(menu:GetWidth() == ROW_WIDTH and menu:GetHeight() == 3 * ROW_HEIGHT, "modern menu is rowWidth x rows")
    assert(boxes[1].left == 0 and boxes[1].top == 0 and boxes[1].right == ROW_WIDTH, "modern first row spans the top edge")
    assert(boxes[3].bottom == 3 * ROW_HEIGHT, "modern last row reaches the bottom edge")
  end
end
