local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local TemplateFactory = require("tests.helpers.template_factory")
local Theme = require("WhisperMessenger.UI.Theme")
local Hud = require("WhisperMessenger.UI.Theme.Hud")
local SettingsControls = require("WhisperMessenger.UI.Shared.SettingsControls")

local SLIDER_TEMPLATE = "OptionsSliderTemplate"
-- OptionsSliderTemplate's thumb art width.
local NATIVE_THUMB = 32

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

local function newSlider(factory, spec)
  local parent = factory.CreateFrame("Frame", nil, nil)
  return SettingsControls.CreateSliderRow(factory, parent, {
    label = "Size",
    min = 0,
    max = 10,
    step = 1,
    initial = spec.initial or 5,
    commitOnRelease = spec.commitOnRelease,
    onChange = spec.onChange,
    formatFn = function(v)
      return tostring(v) .. "px"
    end,
  })
end

local function recorder()
  local calls = {}
  return calls, function(value)
    calls[#calls + 1] = value
  end
end

local function trackBlockers(slider)
  local out = {}
  for _, child in ipairs(FindUI.ofType(slider, "Frame")) do
    if child.mouseEnabled then
      out[#out + 1] = child
    end
  end
  return out
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()
  local width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
  Theme.SetPreset("wow_default")
  Hud.Configure("classic")

  -- test_hud_slider_is_blizzard_options_slider
  do
    local s = newSlider(factory, {})
    assert(s.slider.template == SLIDER_TEMPLATE, "HUD slider: built from " .. SLIDER_TEMPLATE .. ", got " .. tostring(s.slider.template))
    assert(s.slider.frameType == "Slider", "HUD slider: a Slider")
  end

  -- test_hud_slider_draws_no_modern_art
  do
    local s = newSlider(factory, { commitOnRelease = true })
    assert(s.fill == nil and s.thumb == nil, "HUD slider: no custom fill or thumb")
    assert(s.slider.thumbTexture == nil, "HUD slider: keeps the template's thumb")
    assert(#FindUI.ofType(s.slider, "Texture") == 0, "HUD slider: no custom track texture")
  end

  -- test_hud_slider_value_round_trips_with_label
  do
    local s = newSlider(factory, { initial = 4 })
    assert(s.slider:GetValue() == 4 and s.value.text == "4px", "HUD slider: initial value and label")
    s.slider:SetValue(8)
    assert(s.value.text == "8px", "HUD slider: label follows the value")
  end

  -- test_hud_slider_fires_on_change_once_per_user_change
  do
    local calls, onChange = recorder()
    local s = newSlider(factory, { onChange = onChange })
    s.slider:SetValue(3, true)
    assert(#calls == 1 and calls[1] == 3, "HUD slider: one change, one onChange")
  end

  -- test_hud_commit_on_release_commits_once_on_mouse_up
  do
    local calls, onChange = recorder()
    local s = newSlider(factory, { commitOnRelease = true, onChange = onChange })
    s.slider.scripts.OnMouseDown(s.slider, "LeftButton")
    s.slider:SetValue(6, true)
    s.slider:SetValue(7, true)
    assert(#calls == 0, "HUD release slider: dragging does not commit")
    assert(s.value.text == "7px", "HUD release slider: label tracks the drag")
    s.slider.scripts.OnMouseUp(s.slider, "LeftButton")
    assert(#calls == 1 and calls[1] == 7, "HUD release slider: release commits the last value once")
  end

  -- test_hud_commit_on_release_blocks_track_clicks_beside_the_template_thumb
  do
    local s = newSlider(factory, { commitOnRelease = true })
    local blockers = trackBlockers(s.slider)
    local travel = width - NATIVE_THUMB
    assert(#blockers == 2, "HUD release slider: track beside the thumb catches clicks, got " .. #blockers)
    assert(math.abs(blockers[1].width - travel / 2) < 0.01, "HUD release slider: left blocker ends at the thumb, got " .. tostring(blockers[1].width))
    assert(math.abs(blockers[2].width - travel / 2) < 0.01, "HUD release slider: right blocker starts after the thumb")
    s.setWidth(200)
    assert(math.abs(blockers[1].width - (200 - NATIVE_THUMB) / 2) < 0.01, "HUD release slider: blockers follow a resize")
  end

  -- test_hud_slider_labels_keep_preset_colours
  do
    local s = newSlider(factory, {})
    assert(colorsMatch(s.label.textColor, Theme.COLORS.text_primary), "HUD slider: label primary")
    assert(colorsMatch(s.value.textColor, Theme.COLORS.text_primary), "HUD slider: value primary")
    assert(colorsMatch(s.minLabel.textColor, Theme.COLORS.text_timestamp), "HUD slider: min label subtle")
    Theme.SetPreset("plumber_warm")
    s.applyTheme(Theme)
    assert(colorsMatch(s.label.textColor, Theme.COLORS.text_primary), "HUD slider: preset change recolours the label")
    Theme.SetPreset("wow_default")
  end

  -- test_hud_slider_hides_template_labels_when_present
  do
    local s = newSlider(TemplateFactory.withText(factory, SLIDER_TEMPLATE, { "Low", "High", "Text" }), {})
    assert(s.slider.Low.shown == false and s.slider.High.shown == false, "HUD slider: template Low/High hidden")
    assert(s.slider.Text.shown == false, "HUD slider: template title hidden")
  end

  -- test_hud_slider_falls_back_without_template
  do
    local s = newSlider(TemplateFactory.missing(factory, SLIDER_TEMPLATE), {})
    assert(s.slider.template == nil, "fallback: plain slider")
    assert(s.fill ~= nil and s.slider.thumbTexture == s.thumb, "fallback: modern skin")
  end

  Hud.Configure("off")

  -- test_modern_slider_keeps_custom_skin
  do
    local s = newSlider(factory, {})
    assert(s.slider.template == nil and s.fill ~= nil, "modern slider: custom skin")
  end

  Theme.SetPreset(previousPreset)
  print("  All HUD slider tests passed")
end
