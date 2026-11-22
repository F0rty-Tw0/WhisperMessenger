-- On WoW: Forever the Native look keeps WhisperMessenger's own dropdown list,
-- drawn like the game's menus: a tooltip panel, Blizzard list hover art and
-- the quest log's selected-entry art. The modern look is unchanged.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Flavor = require("tests.helpers.flavor")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local NativeArt = require("WhisperMessenger.UI.Helpers.NativeArt")
local DropdownSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")

local TOOLTIP_TEMPLATE = "TooltipBackdropTemplate"

local function option(key, label)
  return { key = key, label = label }
end

local function hasListHover(row)
  return FindUI.find(row, function(n)
    return n.drawLayer == "HIGHLIGHT" and n.texturePath == NativeArt.LIST_HOVER
  end) ~= nil
end

local function hasTooltipPanel(menu)
  return FindUI.find(menu, function(n)
    return n.template == TOOLTIP_TEMPLATE
  end) ~= nil
end

-- Font Family dropdown; `native` builds it on Forever under the Native look
-- (switched off right after Create). `list` is what getOptions returns, so a
-- test can grow it before opening.
local function build(native)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local list = { option("default", "Default"), option("open_sans", "Open Sans"), option("morpheus", "Morpheus") }
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
      onChange = function(key)
        changes[#changes + 1] = key
      end,
    })
  end
  if native then
    Flavor.With(true, true, function()
      Hud.Configure("classic")
      create()
      Hud.Configure("off")
    end)
  else
    create()
  end
  return dropdown, changes, list
end

return function()
  -- test_native_menu_draws_a_tooltip_panel
  do
    local dd = build(true)
    local menu = FindUI.dropdownMenu(dd.row)
    assert(hasTooltipPanel(menu), "native menu has no tooltip panel")
    -- Fake textures start hidden, so assert the paint, not `shown`.
    assert(FindUI.ofType(menu, "Texture")[1].color == nil, "no flat menu background painted under the Native look")
  end

  -- test_native_menu_rows_hover_with_blizzard_list_art
  do
    local dd = build(true)
    local rows = FindUI.dropdownOptions(dd.row)
    assert(#rows == 3, "rows still listed (scroll child stays the menu's first Frame child)")
    assert(hasListHover(rows[1]) and hasListHover(rows[3]), "every row hovers with NativeArt.LIST_HOVER")
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
    local rows = FindUI.dropdownOptions(dd.row)
    assert(rows[2].bg.texturePath == NativeArt.LIST_SELECTED and rows[2].bg.shown == true, "selected row shows LIST_SELECTED")
    assert(rows[1].bg.shown == false, "unselected row shows no selection art")
  end

  -- test_native_rows_pooled_after_create_keep_the_skin
  do
    local dd, _, list = build(true)
    list[4] = option("friz", "Friz Quadrata")
    list[5] = option("arial", "Arial Narrow")
    FindUI.click(dd.button)
    local rows = FindUI.dropdownOptions(dd.row)
    assert(#rows == 5, "the grown list is listed")
    assert(hasListHover(rows[5]), "a row pooled later keeps the native skin")
  end

  -- test_native_menu_pick_still_works
  do
    local dd, changes = build(true)
    FindUI.click(dd.button)
    FindUI.click(FindUI.dropdownOptions(dd.row)[3])
    assert(changes[1] == "morpheus" and not FindUI.dropdownMenu(dd.row):IsShown(), "pick fires onChange and closes the menu")
  end

  -- test_modern_menu_has_no_tooltip_panel
  do
    local modern = build(false)
    assert(not hasTooltipPanel(FindUI.dropdownMenu(modern.row)), "modern: no tooltip panel")
    assert(not hasListHover(FindUI.dropdownOptions(modern.row)[1]), "modern: no Blizzard list art")
  end
end
