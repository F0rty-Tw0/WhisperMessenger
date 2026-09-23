local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local Controls = require("WhisperMessenger.UI.Helpers.Controls")
local ToggleSwitch = require("WhisperMessenger.UI.Helpers.ToggleSwitch")

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

local function trackFill(toggle)
  return toggle.switch.track.fills[2]
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()

  Theme.SetPreset("wow_default")

  -- test_modern_toggle_renders_pill_switch_instead_of_square_dot
  do
    local toggle = newToggle(factory, false)
    assert(type(toggle.switch) == "table", "modern toggle should expose a switch")
    assert(toggle.dot.width == ToggleSwitch.TRACK_WIDTH, "switch hit area should be the track width")
    assert(toggle.dot.height == ToggleSwitch.TRACK_HEIGHT, "switch hit area should be the track height")
    assert(trackFill(toggle).shown == true, "pill track shown")
    assert(toggle.switch.knob.shown == true, "round knob shown")
    assert(toggle.switch.knob.width == ToggleSwitch.KNOB_SIZE, "knob is a small circle")
  end

  -- test_modern_switch_off_is_neutral_track_with_knob_left
  do
    local toggle = newToggle(factory, false)
    assert(colorsMatch(trackFill(toggle).color, Theme.COLORS.option_toggle_off), "off track should be neutral")
    assert(colorsMatch(toggle.switch.track.corners[1].vertexColor, Theme.COLORS.option_toggle_off), "off corners match track")
    assert(toggle.switch.knob.point[1] == "LEFT", "off knob sits on the left")
    assert(colorsMatch(toggle.switch.knob.vertexColor, Theme.COLORS.control_knob), "knob uses control_knob")
  end

  -- test_modern_switch_on_is_accent_track_with_knob_right
  do
    local changes = {}
    local toggle = newToggle(factory, false, function(v)
      changes[#changes + 1] = v
    end)
    toggle.dot:GetScript("OnClick")(toggle.dot)
    assert(changes[1] == true, "click should still fire onChange(true)")
    assert(colorsMatch(trackFill(toggle).color, Theme.COLORS.option_toggle_on), "on track should be the accent toggle colour")
    assert(toggle.switch.knob.point[1] == "RIGHT", "on knob sits on the right")
  end

  -- test_modern_switch_keeps_tooltip
  do
    local toggle = newToggle(factory, true)
    assert(toggle.row.scripts.OnEnter ~= nil, "row tooltip still wired")
  end

  -- test_theme_change_repaints_switch
  do
    local toggle = newToggle(factory, true)
    Theme.SetPreset("plumber_warm")
    toggle.applyThemeColors({ on = Theme.COLORS.option_toggle_on, off = Theme.COLORS.option_toggle_off, knob = Theme.COLORS.control_knob })
    assert(colorsMatch(trackFill(toggle).color, Theme.COLORS.option_toggle_on), "theme change repaints the on track")
  end

  Theme.SetPreset(previousPreset)
  print("  All toggle switch tests passed")
end
