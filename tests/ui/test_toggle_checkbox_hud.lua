local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local Controls = require("WhisperMessenger.UI.Helpers.Controls")
local ToggleSwitch = require("WhisperMessenger.UI.Helpers.ToggleSwitch")

local CHECK_TEMPLATE = "UICheckButtonTemplate"

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

local function newToggle(factory, initial, onChange)
  local parent = factory.CreateFrame("Frame", nil, nil)
  local colors = {
    text = Theme.COLORS.text_primary,
    on = Theme.COLORS.option_toggle_on,
    off = Theme.COLORS.option_toggle_off,
  }
  return Controls.createToggleRow(factory, parent, "Label", initial, colors, { width = 300, height = 24 }, onChange, { "Tip", "Body" })
end

local function hasSwitchArt(row)
  return FindUI.find(row, function(node)
    return node.texturePath == ToggleSwitch.KNOB_TEXTURE
  end) ~= nil
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()
  Theme.SetPreset("wow_default")
  Hud.Configure("classic")

  -- test_hud_toggle_is_blizzard_checkbox
  do
    local toggle = newToggle(factory, false)
    assert(toggle.dot.template == CHECK_TEMPLATE, "HUD toggle: built from " .. CHECK_TEMPLATE .. ", got " .. tostring(toggle.dot.template))
    assert(toggle.dot.frameType == "CheckButton", "HUD toggle: a CheckButton")
    assert(toggle.dot.width == 26 and toggle.dot.height == 26, "HUD toggle: checkbox sized like the game's")
  end

  -- test_hud_toggle_initial_value_sets_the_check
  do
    assert(newToggle(factory, true).dot:GetChecked() == true, "HUD toggle: on starts checked")
    assert(newToggle(factory, false).dot:GetChecked() == false, "HUD toggle: off starts unchecked")
  end

  -- test_hud_toggle_click_fires_on_change_once_per_click
  do
    local changes = {}
    local toggle = newToggle(factory, false, function(value)
      changes[#changes + 1] = value
    end)
    FindUI.click(toggle.dot)
    assert(#changes == 1 and changes[1] == true, "HUD toggle: one click fires onChange(true) once")
    assert(toggle.dot:GetChecked() == true, "HUD toggle: click checks the box")
    FindUI.click(toggle.dot)
    assert(#changes == 2 and changes[2] == false, "HUD toggle: second click fires onChange(false)")
    assert(toggle.dot:GetChecked() == false, "HUD toggle: second click unchecks the box")
  end

  -- test_hud_toggle_set_value_syncs_the_check_without_on_change
  do
    local changes = 0
    local toggle = newToggle(factory, false, function()
      changes = changes + 1
    end)
    toggle.setValue(true)
    assert(toggle.dot:GetChecked() == true, "HUD toggle: setValue(true) checks")
    toggle.setValue(false)
    assert(toggle.dot:GetChecked() == false, "HUD toggle: setValue(false) unchecks")
    assert(changes == 0, "HUD toggle: setValue is not a user change")
  end

  -- test_hud_toggle_draws_no_switch
  do
    local toggle = newToggle(factory, true)
    assert(toggle.switch == nil, "HUD toggle: no switch parts")
    assert(not hasSwitchArt(toggle.row), "HUD toggle: no pill or knob art")
  end

  -- test_hud_toggle_label_keeps_preset_text_colour
  do
    local toggle = newToggle(factory, true)
    assert(colorsMatch(toggle.label.textColor, Theme.COLORS.text_primary), "HUD toggle: label in the preset text colour")
    Theme.SetPreset("plumber_warm")
    toggle.applyThemeColors({ text = Theme.COLORS.text_primary, on = Theme.COLORS.option_toggle_on, off = Theme.COLORS.option_toggle_off })
    assert(colorsMatch(toggle.label.textColor, Theme.COLORS.text_primary), "HUD toggle: preset change recolours the label")
    assert(toggle.dot:GetChecked() == true, "HUD toggle: repaint keeps the check")
    Theme.SetPreset("wow_default")
  end

  -- test_hud_toggle_keeps_tooltip
  do
    assert(newToggle(factory, true).row.scripts.OnEnter ~= nil, "HUD toggle: row tooltip still wired")
  end

  -- test_hud_toggle_hides_template_text_when_present
  do
    local toggle = newToggle(TemplateFactory.withText(factory, CHECK_TEMPLATE, { "Text" }), true)
    assert(toggle.dot.Text.shown == false, "HUD toggle: template's own text hidden; our label is the label")
  end

  -- test_hud_toggle_falls_back_to_switch_without_template
  do
    local changes = {}
    local toggle = newToggle(TemplateFactory.missing(factory, CHECK_TEMPLATE), false, function(value)
      changes[#changes + 1] = value
    end)
    assert(toggle.dot.template == nil, "fallback: plain button")
    assert(type(toggle.switch) == "table", "fallback: modern switch")
    FindUI.click(toggle.dot)
    assert(changes[1] == true and FindUI.isToggleOn(toggle.dot), "fallback: switch still toggles")
  end

  Hud.Configure("off")

  -- test_modern_toggle_keeps_switch
  do
    local toggle = newToggle(factory, true)
    assert(toggle.dot.template == nil and toggle.dot.frameType == "Button", "modern toggle: plain button")
    assert(type(toggle.switch) == "table", "modern toggle: switch")
  end

  Theme.SetPreset(previousPreset)
  print("  All HUD toggle checkbox tests passed")
end
