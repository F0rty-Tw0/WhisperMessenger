-- On WoW: Forever the Native look keeps WhisperMessenger's own dropdown list,
-- drawn like the game's menus: a tooltip panel, Blizzard list hover art and
-- the quest log's selected-entry art. The modern look is unchanged.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Flavor = require("tests.helpers.flavor")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local NativeArt = require("WhisperMessenger.UI.Helpers.NativeArt")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
local DropdownSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")

local TOOLTIP_TEMPLATE = "TooltipBackdropTemplate"
-- Distinct from each other and from the theme's header colour.
local COLORS = { text = { 0.11, 0.22, 0.33, 1 }, textActive = { 0.44, 0.55, 0.66, 1 } }

local function option(key, label)
  return { key = key, label = label }
end

local function fontList()
  return { option("default", "Default"), option("open_sans", "Open Sans"), option("morpheus", "Morpheus") }
end

local function groupedList()
  return { { header = true, label = "Blizzard" }, option("default", "Default"), option("open_sans", "Open Sans") }
end

local function listHover(row)
  return FindUI.find(row, function(n)
    return n.drawLayer == "HIGHLIGHT" and n.texturePath == NativeArt.LIST_HOVER
  end)
end

-- Alpha of the row's Blizzard hover art (0 = hidden); errors when the row has none.
local function hoverAlpha(row)
  local highlight = listHover(row)
  assert(highlight, "row has no NativeArt.LIST_HOVER highlight")
  return highlight:GetAlpha()
end

local function tooltipPanel(menu)
  return FindUI.find(menu, function(n)
    return n.template == TOOLTIP_TEMPLATE
  end)
end

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

-- Runs `fn` on Forever under the Native look, then switches the look off
-- even when `fn` throws.
local function withNativeLook(fn)
  Flavor.With(true, true, function()
    Hud.Configure("classic")
    local ok, err = pcall(fn)
    Hud.Configure("off")
    if not ok then
      error(err, 0)
    end
  end)
end

-- Font Family dropdown; `native` builds it on Forever under the Native look
-- (switched off right after Create). `list` (default fontList()) is what
-- getOptions returns, so a test can change it before opening.
local function build(native, list)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  list = list or fontList()
  local changes = {}
  local dropdown
  local function create()
    dropdown = DropdownSelector.Create(factory, parent, {
      labelText = "Font Family",
      optionsList = list,
      getOptions = function()
        return list
      end,
      fallbackKey = "default",
      initial = "open_sans",
      colors = COLORS,
      onChange = function(key)
        changes[#changes + 1] = key
      end,
    })
  end
  if native then
    withNativeLook(create)
  else
    create()
  end
  return dropdown, changes, list
end

return function()
  -- test_native_menu_draws_a_tooltip_panel
  do
    local dd = build(true)
    assert(tooltipPanel(FindUI.dropdownMenu(dd.row)) ~= nil, "native menu has no tooltip panel")
  end

  -- test_native_menu_paints_no_flat_background
  do
    local dd = build(true)
    -- Fake textures start hidden, so assert the paint, not `shown`.
    assert(FindUI.dropdownMenu(dd.row)._wmBg.color == nil, "no flat menu background painted under the Native look")
  end

  -- test_native_menu_panel_follows_the_menu_level_on_open
  do
    local dd = build(true)
    local menu = FindUI.dropdownMenu(dd.row)
    menu:SetFrameLevel(50)
    FindUI.click(dd.button)
    assert(tooltipPanel(menu):GetFrameLevel() == 50, "panel re-levelled with the menu on open")
  end

  -- test_native_menu_rows_are_listed
  do
    local dd = build(true)
    assert(#FindUI.dropdownOptions(dd.row) == 3, "every option listed")
  end

  -- test_native_menu_rows_hover_with_blizzard_list_art
  do
    local dd = build(true)
    local rows = FindUI.dropdownOptions(dd.row)
    assert(listHover(rows[1]) and listHover(rows[3]), "every row hovers with NativeArt.LIST_HOVER")
  end

  -- test_native_header_row_gets_no_hover_art
  do
    local dd = build(true, groupedList())
    assert(hoverAlpha(FindUI.dropdownOptions(dd.row)[1]) == 0, "header hover art is hidden")
  end

  -- test_native_choice_row_keeps_its_hover_art
  do
    local dd = build(true, groupedList())
    assert(hoverAlpha(FindUI.dropdownOptions(dd.row)[2]) ~= 0, "choice hover art stays visible")
  end

  -- test_native_pooled_header_turned_choice_gets_hover_art_back
  do
    local dd, _, list = build(true, groupedList())
    list[1] = option("friz", "Friz Quadrata")
    FindUI.click(dd.button)
    assert(hoverAlpha(FindUI.dropdownOptions(dd.row)[1]) ~= 0, "a pooled row that becomes a choice hovers again")
  end

  -- test_native_menu_hover_paints_no_flat_wash
  do
    local dd = build(true)
    local rows = FindUI.dropdownOptions(dd.row)
    rows[1].scripts.OnEnter(rows[1])
    assert(rows[1].bg.color == nil, "native hover paints no colour fill")
  end

  -- test_native_menu_marks_the_selected_row
  do
    local dd = build(true)
    local bg = FindUI.dropdownOptions(dd.row)[2].bg
    assert(bg.texturePath == NativeArt.LIST_SELECTED and bg.shown == true, "selected row shows LIST_SELECTED")
  end

  -- test_native_selected_art_is_dimmed
  do
    local dd = build(true)
    local bg = FindUI.dropdownOptions(dd.row)[2].bg
    assert(bg.alpha == NativeArt.LIST_SELECTED_ALPHA, "selected art drawn at LIST_SELECTED_ALPHA, got " .. tostring(bg.alpha))
  end

  -- test_native_unselected_row_shows_no_selection_art
  do
    local dd = build(true)
    assert(FindUI.dropdownOptions(dd.row)[1].bg.shown == false, "unselected row shows no selection art")
  end

  -- test_native_rows_use_the_game_menu_font
  do
    local dd = build(true)
    local label = FindUI.dropdownOptions(dd.row)[1].label
    assert(label.template == PickerPopup.MENU_FONT, "native row font is MENU_FONT, got " .. tostring(label.template))
  end

  -- test_native_header_text_uses_the_secondary_colour
  do
    local dd = build(true, groupedList())
    local label = FindUI.dropdownOptions(dd.row)[1].label
    assert(sameColor(label.textColor, Theme.COLORS.text_secondary), "header text is text_secondary")
  end

  -- test_native_selected_text_uses_the_active_colour
  do
    local dd = build(true)
    local label = FindUI.dropdownOptions(dd.row)[2].label
    assert(sameColor(label.textColor, COLORS.textActive), "selected text is palette.textActive")
  end

  -- test_native_unselected_text_uses_the_text_colour
  do
    local dd = build(true)
    local label = FindUI.dropdownOptions(dd.row)[1].label
    assert(sameColor(label.textColor, COLORS.text), "unselected text is palette.text")
  end

  -- test_native_rows_pooled_after_create_keep_the_skin
  do
    local dd, _, list = build(true)
    list[4] = option("friz", "Friz Quadrata")
    list[5] = option("arial", "Arial Narrow")
    FindUI.click(dd.button)
    local rows = FindUI.dropdownOptions(dd.row)
    assert(#rows == 5, "the grown list is listed")
    assert(listHover(rows[5]), "a row pooled later keeps the native skin")
  end

  -- test_native_menu_pick_fires_on_change
  do
    local dd, changes = build(true)
    FindUI.click(dd.button)
    FindUI.click(FindUI.dropdownOptions(dd.row)[3])
    assert(changes[1] == "morpheus", "pick fires onChange with the picked key")
  end

  -- test_native_menu_pick_closes_the_menu
  do
    local dd = build(true)
    FindUI.click(dd.button)
    FindUI.click(FindUI.dropdownOptions(dd.row)[3])
    assert(not FindUI.dropdownMenu(dd.row):IsShown(), "pick closes the menu")
  end

  -- test_modern_menu_has_no_tooltip_panel
  do
    local modern = build(false)
    assert(tooltipPanel(FindUI.dropdownMenu(modern.row)) == nil, "modern: no tooltip panel")
  end

  -- test_modern_menu_rows_have_no_blizzard_list_art
  do
    local modern = build(false)
    assert(listHover(FindUI.dropdownOptions(modern.row)[1]) == nil, "modern: no Blizzard list art")
  end
end
