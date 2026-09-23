local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Controls = require("WhisperMessenger.UI.Helpers.Controls")
local NavItem = require("WhisperMessenger.UI.Helpers.NavItem")
local GhostButton = require("WhisperMessenger.UI.Helpers.GhostButton")
local OptionsMenuButtons = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.OptionsMenuButtons")
local SettingsTabs = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.SettingsTabs")

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
  local header = menu:CreateFontString(nil, "OVERLAY")
  return OptionsMenuButtons.Build(factory, menu, header, { theme = Theme, menuPadding = 16, contactsWidth = 260 })
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()

  Theme.SetPreset("wow_default")

  -- test_modern_nav_rest_is_left_aligned_text_without_box
  do
    local nav = newNav(factory)
    assert(nav.bg.color[4] == 0, "no box at rest")
    assert(nav.label.point[1] == "LEFT" and nav.label.point[4] == NavItem.PADDING_X, "label left-aligned with padding")
    assert(colorsMatch(nav.label.textColor, Theme.COLORS.text_secondary), "rest text is secondary")
    assert(nav.nav.bar.shown ~= true, "no accent bar at rest")
    assert(nav.nav.selection.shown ~= true, "no selection fade at rest")
  end

  -- test_modern_nav_hover_is_faint_wash
  do
    local nav = newNav(factory)
    nav.scripts.OnEnter(nav)
    assert(nav.nav.hover.shown == true, "hover wash shown")
    assert(rgbMatch(nav.nav.hover.color, Theme.COLORS.bg_contact_hover), "hover wash uses contact hover")
    assert(colorsMatch(nav.label.textColor, Theme.COLORS.text_primary), "hover text primary")
    nav.scripts.OnLeave(nav)
    assert(nav.nav.hover.shown ~= true, "hover wash hidden on leave")
  end

  -- test_modern_nav_selected_is_accent_fade_and_bar
  do
    local nav = newNav(factory)
    nav.setNavActive(true)
    assert(nav.nav.selection.shown == true, "selection fade shown")
    assert(rgbMatch(nav.nav.selection.color, Theme.COLORS.bg_contact_selected), "selection uses bg_contact_selected")
    assert(nav.nav.bar.shown == true, "accent bar shown")
    assert(nav.nav.bar.width == Theme.LAYOUT.CONTACT_ACCENT_BAR_W, "bar matches contact rows")
    assert(colorsMatch(nav.nav.bar.color, Theme.COLORS.accent_bar), "bar uses accent_bar")
    assert(colorsMatch(nav.label.textColor, Theme.COLORS.text_primary), "selected text primary")
    assert(nav.bg.color[4] == 0, "selected still has no box")
    nav.setNavActive(false)
    assert(nav.nav.bar.shown ~= true, "deselect hides bar")
  end

  -- test_settings_tabs_drive_nav_selection_without_box_paint
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
    assert(menu.generalTab.nav.bar.shown == true, "first tab selected by default")
    assert(menu.generalTab.bg.color[4] == 0, "tab wiring must not paint a box under modern")
    menu.appearanceTab.scripts.OnClick(menu.appearanceTab)
    assert(menu.appearanceTab.nav.bar.shown == true, "clicked tab selected")
    assert(menu.generalTab.nav.bar.shown ~= true, "previous tab deselected")
    menu.generalTab.scripts.OnEnter(menu.generalTab)
    assert(menu.generalTab.nav.hover.shown == true, "tab hover wash after wiring")
  end

  -- test_menu_utility_buttons_are_ghosts_and_clear_is_danger
  do
    local menu = buildMenu(factory)
    assert(menu.resetWindowButton.ghost ~= nil, "Reset Window is a ghost button")
    assert(menu.resetIconButton.ghost ~= nil, "Reset Icon is a ghost button")
    local clear = menu.clearAllChatsButton
    assert(clear.ghost ~= nil and clear.ghost.danger == true, "Clear All Chats is a danger ghost")
    assert(clear.bg.color[4] == 0, "danger ghost has no solid red block")
    assert(colorsMatch(clear.label.textColor, Theme.COLORS.danger_text), "danger ghost text is red")
    assert(rgbMatch(clear.ghost.border.top.color, Theme.COLORS.danger_text), "danger ghost outline is red")
    assert(clear.ghost.border.top.color[4] == GhostButton.DANGER_BORDER_ALPHA, "danger outline is soft")
    clear.scripts.OnEnter(clear)
    assert(clear.ghost.hover.shown == true, "danger hover wash shown")
    assert(rgbMatch(clear.ghost.hover.color, Theme.COLORS.danger_text), "danger hover wash is red")
    assert(clear.ghost.hover.alpha == GhostButton.DANGER_WASH_ALPHA, "danger wash is faint")
  end

  Theme.SetPreset(previousPreset)
  print("  All modern options nav tests passed")
end
