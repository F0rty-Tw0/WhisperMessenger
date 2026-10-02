local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Localization = require("WhisperMessenger.Locale.Localization")
local PickerPopup = require("WhisperMessenger.UI.Shared.PickerPopup")
local PickerStyles = require("WhisperMessenger.UI.Shared.PickerStyles")

-- Under the Native WoW HUD the small popups use Blizzard's tooltip frame and
-- dropdown-menu art; the modern look keeps its flat themed panel.

local TOOLTIP_BACKGROUND = "Interface\\Tooltips\\UI-Tooltip-Background"
local TOOLTIP_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local MENU_HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestTitleHighlight"

local function hasFlatFill(frame)
  return FindUI.find(frame, function(node)
    return node.frameType == "Texture" and node.color ~= nil
  end) ~= nil
end

local function copy(color)
  return { color[1], color[2], color[3], color[4] }
end

local function sameColor(a, b)
  return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]
end

return function()
  Localization.Configure({ language = "enUS" })
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local noTooltipTemplate = TemplateFactory.missing(factory, "TooltipBackdropTemplate")

  Hud.Configure("classic")

  -- test_hud_panel_uses_tooltip_backdrop_template
  do
    local panel = PickerPopup.CreatePanel(factory, parent, nil, "DIALOG")
    assert(panel.template == "TooltipBackdropTemplate", "HUD panel template, got " .. tostring(panel.template))
  end

  -- test_hud_panel_paints_no_flat_background_or_border
  do
    local panel = PickerPopup.CreatePanel(factory, parent, nil, "DIALOG")
    assert(panel._background == nil and panel._border == nil, "HUD panel has no custom background or border")
    assert(not hasFlatFill(panel), "HUD panel paints no flat colour")
  end

  -- test_hud_panel_falls_back_to_tooltip_backdrop
  do
    local panel = PickerPopup.CreatePanel(noTooltipTemplate, parent, nil, "DIALOG")
    assert(panel.template == "BackdropTemplate", "fallback template, got " .. tostring(panel.template))
    local backdrop = panel.backdrop or {}
    assert(backdrop.bgFile == TOOLTIP_BACKGROUND, "fallback background art")
    assert(backdrop.edgeFile == TOOLTIP_BORDER, "fallback border art")
    assert(backdrop.edgeSize == 16 and backdrop.insets and backdrop.insets.left == 4, "fallback edge size and insets")
    assert(panel.backdropColor and panel.backdropColor[4] == 0.9, "fallback background is 90% opaque")
    assert(panel.backdropBorderColor ~= nil, "fallback border colour set")
    assert(not hasFlatFill(panel), "fallback panel paints no flat colour")
  end

  -- test_theme_refresh_leaves_native_panel_alone
  do
    local panel = PickerPopup.CreatePanel(noTooltipTemplate, parent, nil, "DIALOG")
    local background = copy(panel.backdropColor)
    local border = copy(panel.backdropBorderColor)
    PickerStyles.ApplyPanelTheme(panel, panel._border)
    assert(sameColor(panel.backdropColor, background), "theme refresh keeps tooltip background")
    assert(sameColor(panel.backdropBorderColor, border), "theme refresh keeps tooltip border")
    assert(not hasFlatFill(panel), "theme refresh paints no flat colour")
  end

  -- test_hud_text_button_uses_blizzard_font
  do
    local panel = PickerPopup.CreatePanel(factory, parent, nil, "DIALOG")
    local _, label = PickerPopup.CreateTextButton(factory, panel, "Reply", function() end)
    assert(label.fontObject == rawget(_G, "GameFontHighlight"), "HUD text button font is GameFontHighlight")
    assert(label.textColor == nil, "HUD text button keeps the font object's own colour")
    assert(label.text == "Reply", "HUD text button label")
  end

  -- test_hud_text_button_hover_is_dropdown_menu_art
  do
    local panel = PickerPopup.CreatePanel(factory, parent, nil, "DIALOG")
    local button = PickerPopup.CreateTextButton(factory, panel, "Reply", function() end)
    local highlight = button.highlightTexture
    assert(type(highlight) == "table", "HUD text button sets a highlight texture")
    assert(highlight.texturePath == MENU_HIGHLIGHT, "highlight art, got " .. tostring(highlight.texturePath))
    assert(highlight.blendMode == "ADD", "highlight blends additively")
    assert(highlight.drawLayer == "HIGHLIGHT", "highlight lives on the HIGHLIGHT layer")
    assert(not hasFlatFill(button), "HUD text button has no flat colour fill")
  end

  Hud.Configure("off")

  -- test_modern_panel_keeps_flat_background_and_border
  do
    local panel = PickerPopup.CreatePanel(factory, parent, nil, "DIALOG")
    assert(panel.template == nil, "modern panel has no template")
    assert(panel._background ~= nil and panel._border ~= nil, "modern panel background and border")
    PickerStyles.ApplyPanelTheme(panel, panel._border)
    assert(sameColor(panel._background.color, PickerStyles.BackgroundColor()), "modern panel themed background")
  end

  -- test_modern_text_button_keeps_flat_hover
  do
    local panel = PickerPopup.CreatePanel(factory, parent, nil, "DIALOG")
    local button = PickerPopup.CreateTextButton(factory, panel, "Reply", function() end)
    assert(button.highlightTexture == nil, "modern text button sets no Blizzard highlight")
    button.scripts.OnEnter(button)
    assert(sameColor(button._highlight.color, PickerStyles.HighlightColor(0.35)), "modern hover is the themed fill")
  end
end
