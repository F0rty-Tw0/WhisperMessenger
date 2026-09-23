local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")
local SliderSkin = require("WhisperMessenger.UI.Shared.SettingsControls.SliderSkin")

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

local function newSlider(factory, initial)
  local parent = factory.CreateFrame("Frame", nil, nil)
  return SettingsControls.CreateSliderRow(factory, parent, {
    label = "Size",
    min = 0,
    max = 10,
    step = 1,
    initial = initial,
    formatFn = function(v)
      return tostring(v) .. "px"
    end,
  })
end

local function expectedFill(width, value)
  local knob = SliderSkin.THUMB_SIZE
  return knob / 2 + (value / 10) * (width - knob)
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()
  local width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH

  Theme.SetPreset("wow_default")

  -- test_modern_slider_track_is_thin
  do
    local s = newSlider(factory, 5)
    -- The track is the slider's first texture.
    local track = FindUI.ofType(s.slider, "Texture")[1]
    assert(track.height == SliderSkin.TRACK_HEIGHT, "modern track should be a thin line, got " .. tostring(track.height))
    assert(colorsMatch(track.color, Theme.COLORS.slider_track), "modern track uses slider_track")
  end

  -- test_modern_slider_fill_tracks_value
  do
    local s = newSlider(factory, 5)
    assert(s.fill.shown == true, "accent fill shown under modern")
    assert(colorsMatch(s.fill.color, Theme.COLORS.slider_fill), "fill uses slider_fill")
    assert(math.abs(s.fill.width - expectedFill(width, 5)) < 0.01, "fill ends at thumb centre for 5, got " .. tostring(s.fill.width))
    s.slider:SetValue(10)
    assert(math.abs(s.fill.width - expectedFill(width, 10)) < 0.01, "fill follows value to max")
    s.slider:SetValue(0)
    assert(math.abs(s.fill.width - expectedFill(width, 0)) < 0.01, "fill shrinks to min")
    s.setWidth(200)
    assert(math.abs(s.fill.width - (SliderSkin.THUMB_SIZE / 2)) < 0.01, "fill recomputed after resize")
    s.slider:SetValue(10)
    assert(math.abs(s.fill.width - (200 - SliderSkin.THUMB_SIZE / 2)) < 0.01, "fill uses new width")
  end

  -- test_modern_slider_thumb_is_small_circle
  do
    local s = newSlider(factory, 5)
    assert(s.slider.thumbTexture == s.thumb, "slider uses our own thumb texture")
    assert(s.thumb.width == SliderSkin.THUMB_SIZE and s.thumb.height == SliderSkin.THUMB_SIZE, "thumb is small")
    assert(s.thumb.texturePath == SliderSkin.CIRCLE_TEXTURE, "thumb is a circle")
    assert(colorsMatch(s.thumb.vertexColor, Theme.COLORS.control_knob), "thumb uses control_knob")
  end

  -- test_modern_slider_value_once_and_subtle_range_labels
  do
    local s = newSlider(factory, 5)
    assert(s.value.text == "5px", "value shown top-right")
    assert(colorsMatch(s.value.textColor, Theme.COLORS.text_primary), "value reads as primary")
    assert(colorsMatch(s.minLabel.textColor, Theme.COLORS.text_timestamp), "min label subtle")
    assert(colorsMatch(s.maxLabel.textColor, Theme.COLORS.text_timestamp), "max label subtle")
  end

  -- test_theme_change_repaints_slider
  do
    local s = newSlider(factory, 5)
    Theme.SetPreset("plumber_warm")
    s.applyTheme(Theme)
    assert(colorsMatch(s.fill.color, Theme.COLORS.slider_fill), "theme change repaints the fill")
    assert(colorsMatch(s.thumb.vertexColor, Theme.COLORS.control_knob), "theme change repaints the thumb")
  end

  Theme.SetPreset(previousPreset)
  print("  All modern slider tests passed")
end
