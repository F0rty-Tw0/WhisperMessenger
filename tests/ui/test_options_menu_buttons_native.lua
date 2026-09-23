local FakeUI = require("tests.helpers.fake_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local Theme = require("WhisperMessenger.UI.Theme")
local OptionsMenuButtons = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.OptionsMenuButtons")
local ChromeBuilder = require("WhisperMessenger.UI.MessengerWindow.ChromeBuilder")
local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")

local function build(factory, nativeChrome)
  local menu = factory.CreateFrame("Frame", nil, nil)
  local header = menu:CreateFontString(nil, "OVERLAY")
  return OptionsMenuButtons.Build(factory, menu, header, { menuPadding = 8, contactsWidth = 260, nativeChrome = nativeChrome })
end

local function actionButtons(result)
  return { result.resetWindowButton, result.resetIconButton, result.clearAllChatsButton }
end

return function()
  -- test_hud_action_buttons_use_ui_panel_button_template
  do
    local result = build(FakeUI.NewFactory(), true)
    for _, button in ipairs(actionButtons(result)) do
      assert(button.template == "UIPanelButtonTemplate", "HUD: action buttons should use UIPanelButtonTemplate")
      assert(button.width == 244, "HUD: action button keeps the menu width, got " .. tostring(button.width))
    end
    assert(result.resetWindowButton.text == "Reset Window", "HUD: Reset Window label")
    assert(result.resetIconButton.text == "Reset Icon", "HUD: Reset Icon label")
    assert(result.clearAllChatsButton.text == "Clear All Chats", "HUD: Clear All Chats label")
  end

  -- test_hud_nav_tabs_stay_modern
  do
    local result = build(FakeUI.NewFactory(), true)
    assert(result.generalTab.template == nil and result.generalTab.label ~= nil, "HUD: settings nav list unchanged")
  end

  -- test_hud_action_buttons_relabel_on_language_change
  do
    local result = build(FakeUI.NewFactory(), true)
    result.resetWindowButton:SetText("")
    result.setLanguage()
    assert(result.resetWindowButton.text == "Reset Window", "HUD: setLanguage relabels template buttons")
  end

  -- test_hud_action_buttons_fall_back_when_template_missing
  do
    local factory = TemplateFactory.missing(FakeUI.NewFactory(), "UIPanelButtonTemplate")
    local result = build(factory, true)
    assert(result.resetWindowButton.template == nil and result.resetWindowButton.label ~= nil, "fallback: modern ghost button")
  end

  -- test_modern_action_buttons_unchanged
  do
    local result = build(FakeUI.NewFactory(), false)
    for _, button in ipairs(actionButtons(result)) do
      assert(button.template == nil, "modern: custom ghost buttons")
      assert(button.label ~= nil and button.applyThemeColors ~= nil, "modern: themed label + paint hook")
    end
    assert(result.clearAllChatsButton.label.text == "Clear All Chats", "modern: own label")
  end

  -- test_hud_layout_theme_does_not_repaint_blizzard_buttons
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local chrome = ChromeBuilder.Build(factory, parent, { width = 920, height = 580 }, { useNativeChrome = true })
    local layout = LayoutBuilder.Build(factory, chrome.frame, { width = 920, height = 580 }, {})
    assert(layout.clearAllChatsButton.template == "UIPanelButtonTemplate", "HUD layout: native action buttons")
    layout.applyTheme(Theme)
    assert(layout.clearAllChatsButton.textColor == nil, "HUD: theme must not recolour the Blizzard button")
  end
end
