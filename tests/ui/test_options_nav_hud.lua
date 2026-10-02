local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Controls = require("WhisperMessenger.UI.Helpers.Controls")
local OptionsMenuButtons = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.OptionsMenuButtons")
local SettingsTabs = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.SettingsTabs")

-- Same art and strengths as the contact rows (RowHoverOverlay).
local SELECTED_ART = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"
local HOVER_ART = "Interface\\QuestFrame\\UI-QuestTitleHighlight"
local SELECTED_ALPHA = 0.45
local HOVER_ALPHA = 0.18

local function colorsMatch(actual, expected)
  if type(actual) ~= "table" or type(expected) ~= "table" then
    return false
  end
  for i = 1, 4 do
    if math.abs((actual[i] or 1) - (expected[i] or 1)) > 0.0001 then
      return false
    end
  end
  return true
end

local function rgbMatch(actual, expected)
  return type(actual) == "table"
    and math.abs(actual[1] - expected[1]) < 0.0001
    and math.abs(actual[2] - expected[2]) < 0.0001
    and math.abs(actual[3] - expected[3]) < 0.0001
end

local function assertNativeArt(texture, path, label)
  assert(texture.texturePath == path, label .. ": Blizzard art " .. path .. ", got " .. tostring(texture.texturePath))
  assert(texture.blendMode == "ADD", label .. ": additive blend")
  assert(texture._wmNativeArt == true, label .. ": flagged as native art")
  assert(texture.color == nil, label .. ": no flat colour fill")
end

local function tabColors()
  return {
    bg = Theme.COLORS.option_button_bg,
    bgHover = Theme.COLORS.option_button_hover,
    text = Theme.COLORS.option_button_text,
    textHover = Theme.COLORS.option_button_text_hover,
  }
end

local function newNav(factory)
  return Controls.createOptionButton(factory, nil, "General", tabColors(), { width = 200, height = 30, nav = true })
end

local function buildMenu(factory)
  local menu = factory.CreateFrame("Frame", nil, nil)
  return OptionsMenuButtons.Build(factory, menu, { theme = Theme, menuPadding = 16, contactsWidth = 260, nativeChrome = true })
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()
  Theme.SetPreset("wow_default")
  Hud.Configure("classic")

  -- test_hud_nav_uses_blizzard_list_art_and_no_accent_bar
  do
    local nav = newNav(factory)
    assertNativeArt(nav.nav.selection, SELECTED_ART, "HUD nav selection")
    assertNativeArt(nav.nav.hover, HOVER_ART, "HUD nav hover")
    assert(nav.nav.bar == nil, "HUD nav: no accent bar")
    assert(nav.bg.color[4] == 0, "HUD nav: no box at rest")
    assert(colorsMatch(nav.label.textColor, Theme.COLORS.text_secondary), "HUD nav: rest text keeps the preset colour")
  end

  -- test_hud_nav_selected_is_quest_log_highlight_in_preset_colour
  do
    local nav = newNav(factory)
    nav.setNavActive(true)
    local selection = nav.nav.selection
    assert(selection.shown == true, "HUD nav selected: art shown")
    assert(rgbMatch(selection.vertexColor, Theme.COLORS.bg_contact_selected), "HUD nav selected: tinted with bg_contact_selected")
    assert(math.abs(selection.vertexColor[4] - SELECTED_ALPHA) < 0.0001, "HUD nav selected: contact-row strength")
    assert(colorsMatch(nav.label.textColor, Theme.COLORS.text_primary), "HUD nav selected: text primary")
    assertNativeArt(selection, SELECTED_ART, "HUD nav selected repaint")
    nav.setNavActive(false)
    assert(selection.shown ~= true, "HUD nav deselect: art hidden")
  end

  -- test_hud_nav_hover_is_menu_highlight_in_preset_colour
  do
    local nav = newNav(factory)
    nav.scripts.OnEnter(nav)
    local hover = nav.nav.hover
    assert(hover.shown == true, "HUD nav hover: art shown")
    assert(rgbMatch(hover.vertexColor, Theme.COLORS.bg_contact_hover), "HUD nav hover: tinted with bg_contact_hover")
    assert(math.abs(hover:GetAlpha() - HOVER_ALPHA) < 0.0001, "HUD nav hover: faint, got " .. tostring(hover:GetAlpha()))
    assert(colorsMatch(nav.label.textColor, Theme.COLORS.text_primary), "HUD nav hover: text primary")
    assertNativeArt(hover, HOVER_ART, "HUD nav hover repaint")
    nav.scripts.OnLeave(nav)
    assert(hover.shown ~= true, "HUD nav hover: hidden on leave")
  end

  -- test_hud_nav_theme_refresh_retints_without_flat_fill
  do
    local nav = newNav(factory)
    nav.setNavActive(true)
    Theme.SetPreset("plumber_warm")
    nav.applyThemeColors(tabColors())
    assert(rgbMatch(nav.nav.selection.vertexColor, Theme.COLORS.bg_contact_selected), "HUD nav refresh: re-tinted")
    assertNativeArt(nav.nav.selection, SELECTED_ART, "HUD nav refresh")
    assert(nav.bg.color[4] == 0, "HUD nav refresh: still no box")
    Theme.SetPreset("wow_default")
  end

  -- test_hud_settings_tabs_select_with_native_art
  do
    local menu = buildMenu(factory)
    local panels = {}
    for i = 1, 6 do
      panels[i] = factory.CreateFrame("Frame", nil, nil)
    end
    SettingsTabs.Wire({
      settingsTabs = { menu.generalTab, menu.appearanceTab, menu.behaviorTab, menu.notificationsTab, menu.iconsTab, menu.whatsNewTab },
      settingsPanels = panels,
      theme = Theme,
      scrollView = {},
      measurePanelContentHeight = function()
        return 0
      end,
    })
    assert(menu.generalTab.nav.selection.shown == true, "HUD tabs: first tab selected")
    assert(menu.generalTab.bg.color[4] == 0, "HUD tabs: wiring paints no box")
    menu.appearanceTab.scripts.OnClick(menu.appearanceTab)
    assert(menu.appearanceTab.nav.selection.shown == true, "HUD tabs: clicked tab selected")
    assert(menu.generalTab.nav.selection.shown ~= true, "HUD tabs: previous tab deselected")
    assertNativeArt(menu.appearanceTab.nav.selection, SELECTED_ART, "HUD tabs selection")
  end

  Hud.Configure("off")
  Theme.SetPreset(previousPreset)
  print("  All HUD options nav tests passed")
end
