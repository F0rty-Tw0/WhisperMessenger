local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Controls = require("WhisperMessenger.UI.Helpers.Controls")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")

local BUTTON_TEMPLATE = "UIPanelButtonTemplate"

local function newButton(factory, layout)
  local parent = factory.CreateFrame("Frame", nil, nil)
  return Controls.createOptionButton(factory, parent, "Reset to Defaults", SettingsControls.OptionButtonColors(Theme), layout)
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()
  Theme.SetPreset("wow_default")
  Hud.Configure("classic")

  -- test_hud_option_button_is_blizzard_panel_button
  do
    local button = newButton(factory, { width = 160, height = 26 })
    assert(button.template == BUTTON_TEMPLATE, "HUD button: built from " .. BUTTON_TEMPLATE .. ", got " .. tostring(button.template))
    assert(button:GetText() == "Reset to Defaults", "HUD button: template draws the text")
    assert(button.width == 160 and button.height == 26, "HUD button: keeps the requested size")
    assert(button.bg == nil, "HUD button: no flat fill")
  end

  -- test_hud_ghost_and_danger_buttons_are_plain_panel_buttons
  do
    local ghost = newButton(factory, { width = 160, ghost = true })
    local danger = newButton(factory, { width = 160, ghost = true, danger = true })
    assert(ghost.template == BUTTON_TEMPLATE and ghost.ghost == nil, "HUD ghost: plain panel button, no outline")
    assert(danger.template == BUTTON_TEMPLATE and danger.ghost == nil, "HUD danger: plain panel button, no red outline")
  end

  -- test_hud_button_keeps_the_caller_api
  do
    local button = newButton(factory, { width = 160, height = 26 })
    button.label:SetText("Zurücksetzen")
    assert(button:GetText() == "Zurücksetzen", "HUD button: .label:SetText relabels the button")
    button.setWidth(240)
    assert(button.width == 240 and button.height == 26, "HUD button: setWidth resizes")
    button.applyThemeColors(SettingsControls.OptionButtonColors(Theme))
    assert(button.bg == nil, "HUD button: theme refresh paints nothing")
    local clicks = 0
    button:SetScript("OnClick", function()
      clicks = clicks + 1
    end)
    FindUI.click(button)
    assert(clicks == 1, "HUD button: OnClick wiring unchanged")
  end

  -- test_hud_nav_items_stay_list_items
  do
    local nav = newButton(factory, { width = 160, nav = true })
    assert(nav.template == nil and nav.nav ~= nil, "HUD nav: not a panel button")
  end

  -- test_hud_button_falls_back_without_template
  do
    local button = newButton(TemplateFactory.missing(factory, BUTTON_TEMPLATE), { width = 160, ghost = true })
    assert(button.template == nil and button.ghost ~= nil, "fallback: modern ghost button")
  end

  Hud.Configure("off")

  -- test_modern_button_keeps_custom_look
  do
    local button = newButton(factory, { width = 160 })
    assert(button.template == nil and button.bg ~= nil, "modern button: custom fill")
  end

  Theme.SetPreset(previousPreset)
  print("  All HUD option button tests passed")
end
