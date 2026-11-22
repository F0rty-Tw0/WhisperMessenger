-- Under the Native look the open list sits inside a tooltip panel: the
-- scrolling (clipping) list is inset by the panel's border on every side,
-- so rows and their hover / selected art never draw on the border at any
-- scroll offset. The modern list keeps its edge-to-edge rows.
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
local TOOLTIP_TEMPLATE = "TooltipBackdropTemplate"

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

local function findPanel(root)
  return FindUI.find(root, function(n)
    return n.template == TOOLTIP_TEMPLATE
  end)
end

local function panelOf(dd)
  return assert(findPanel(dd.row), "tooltip panel is drawn")
end

-- The SetPoint call anchoring `frame` by `point`, as { relativeTo, relativePoint, x, y }.
local function anchor(frame, point)
  for _, p in ipairs(frame.points or {}) do
    if p[1] == point then
      return { p[2], p[3], p[4], p[5] }
    end
  end
  error("no " .. point .. " anchor")
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

return function()
  -- test_native_panel_is_outside_the_clipping_list
  do
    local dd = build(true, 3)
    panelOf(dd)
    assert(findPanel(FindUI.dropdownMenu(dd.row)) == nil, "panel is not a child of the list, which clips its children")
  end

  -- test_native_panel_wraps_the_list_by_the_border
  do
    local dd = build(true, 3)
    local menu, panel = FindUI.dropdownMenu(dd.row), panelOf(dd)
    local tl, br = anchor(panel, "TOPLEFT"), anchor(panel, "BOTTOMRIGHT")
    assert(tl[1] == menu and tl[2] == "TOPLEFT" and tl[3] == -INSET and tl[4] == INSET, "panel's top-left is one border outside the list")
    assert(br[1] == menu and br[2] == "BOTTOMRIGHT" and br[3] == INSET and br[4] == -INSET, "panel's bottom-right is one border outside the list")
  end

  -- test_native_list_hangs_one_border_inside_under_the_button
  do
    local dd = build(true, 3)
    local tl = anchor(FindUI.dropdownMenu(dd.row), "TOPLEFT")
    assert(tl[1] == dd.button and tl[2] == "BOTTOMLEFT" and tl[3] == INSET and tl[4] == -2 - INSET, "list sits a border inside the panel's corner")
  end

  -- test_native_panel_keeps_the_button_width
  do
    local menu = FindUI.dropdownMenu(build(true, 3).row)
    assert(menu:GetWidth() + 2 * INSET == ROW_WIDTH, "panel is as wide as the button, list " .. menu:GetWidth())
  end

  -- test_native_list_shows_the_same_number_of_rows
  do
    local menu = FindUI.dropdownMenu(build(true, 40).row)
    assert(menu:GetHeight() == MENU_HEIGHT, "list area is menuHeight tall, got " .. menu:GetHeight())
  end

  -- test_native_rows_fill_the_list_width
  do
    local dd = build(true, 3)
    local menu = FindUI.dropdownMenu(dd.row)
    for i, box in ipairs(rowBoxes(FindUI.dropdownOptions(dd.row))) do
      assert(box.left == 0 and box.right == menu:GetWidth(), "row " .. i .. " spans the list, " .. box.left .. ".." .. box.right)
    end
  end

  -- test_native_scroll_range_is_unchanged
  do
    local native = FindUI.dropdownMenu(build(true, 40).row)
    local modern = FindUI.dropdownMenu(build(false, 40).row)
    assert(native:GetVerticalScrollRange() == modern:GetVerticalScrollRange(), "native scroll range matches the modern one")
  end

  -- test_native_open_scrolls_the_selected_row_into_view
  do
    -- Row 6 ends at 156: past a 150 list area.
    local dd = build(true, 40, "font6", 150)
    local menu = FindUI.dropdownMenu(dd.row)
    FindUI.click(dd.button)
    local box = rowBoxes(FindUI.dropdownOptions(dd.row))[6]
    local offset = menu:GetVerticalScroll()
    assert(box.top >= offset and box.bottom <= offset + menu:GetHeight(), "selected row in view, offset " .. offset)
  end

  -- test_native_panel_shows_and_hides_with_the_list
  do
    local dd = build(true, 3)
    local panel = panelOf(dd)
    assert(not panel:IsShown(), "closed: no panel")
    FindUI.click(dd.button)
    assert(panel:IsShown(), "open: panel shown")
    FindUI.click(dd.button)
    assert(not panel:IsShown(), "closed again: panel hidden")
    FindUI.click(dd.button)
    DropdownSelector.HideShownMenu()
    assert(not panel:IsShown(), "controller B: panel hidden")
  end

  -- test_modern_rows_fill_the_menu_edge_to_edge
  do
    local dd = build(false, 3)
    local menu = FindUI.dropdownMenu(dd.row)
    local boxes = rowBoxes(FindUI.dropdownOptions(dd.row))
    assert(findPanel(dd.row) == nil, "modern: no tooltip panel")
    assert(menu:GetWidth() == ROW_WIDTH and menu:GetHeight() == 3 * ROW_HEIGHT, "modern menu is rowWidth x rows")
    assert(boxes[1].left == 0 and boxes[1].top == 0 and boxes[1].right == ROW_WIDTH, "modern first row spans the top edge")
    assert(boxes[3].bottom == 3 * ROW_HEIGHT, "modern last row reaches the bottom edge")
  end
end
