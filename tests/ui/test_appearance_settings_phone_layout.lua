local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local BehaviorSettings = require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings")

local LABEL = "Phone-style window"

local function create(config)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local changes = {}
  local result = AppearanceSettings.Create(factory, parent, config or {}, {
    onChange = function(key, value)
      changes[#changes + 1] = { key = key, value = value }
    end,
  })
  return result, changes
end

local function changed(changes, key)
  for _, change in ipairs(changes) do
    if change.key == key then
      return change
    end
  end
  return nil
end

return function()
  -- test_the_window_style_toggle_lives_on_the_appearance_page
  do
    local result = create()
    assert(FindUI.byLabel(result.frame, LABEL) ~= nil, "on Appearance")
  end

  -- test_the_window_style_toggle_left_the_behavior_page
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local behavior = BehaviorSettings.Create(factory, parent, {}, {})
    assert(FindUI.text(behavior.frame, LABEL) == nil, "only in one place")
  end

  -- test_reset_returns_the_window_style_to_its_default
  do
    local result, changes = create({ phoneLayout = false })
    local reset = FindUI.byLabel(result.frame, "Reset to Defaults")
    reset.scripts.OnClick(reset)
    local change = changed(changes, "phoneLayout")
    assert(change ~= nil and change.value == true, "the default is the phone window")
  end

  -- test_the_toggle_sits_between_the_hud_picker_and_the_theme_preset
  do
    local result = create()
    local row = FindUI.byLabel(result.frame, LABEL)
    local hud = FindUI.byLabel(result.frame, "Native WoW HUD")
    local preset = FindUI.byLabel(result.frame, "Theme Preset")
    assert(select(2, row:GetPoint()) == hud, "below the HUD picker")
    assert(select(2, preset:GetPoint()) == row, "above the theme preset")
  end

  -- test_the_toggle_relabels_with_the_page
  do
    local result = create()
    assert(type(result.setLanguage) == "function")
    result.setLanguage()
    assert(FindUI.byLabel(result.frame, LABEL) ~= nil, "label survives a language refresh")
  end
end
