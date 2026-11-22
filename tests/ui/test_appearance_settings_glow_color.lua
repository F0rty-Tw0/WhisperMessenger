-- "Glow color" on Appearance: one button per theme preset plus Custom (the
-- game's colour picker), right under Edge glow.
local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local AppearanceSettings = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings")
local Theme = require("WhisperMessenger.UI.Theme")

local LABEL = "Glow color"

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

local function lastChange(changes, key)
  local found
  for _, change in ipairs(changes) do
    if change.key == key then
      found = change
    end
  end
  return found
end

local function selectedKey(result)
  for _, btn in ipairs(FindUI.selectorButtons(result.frame, LABEL)) do
    if btn._selected then
      return btn._key
    end
  end
end

local function customButton(result)
  local buttons = FindUI.selectorButtons(result.frame, LABEL)
  return buttons[#buttons]
end

-- A modern picker stub: records the info table.
local function withPicker(fn)
  local frame = { rgb = { 0, 0, 0 } }
  function frame:GetColorRGB()
    return self.rgb[1], self.rgb[2], self.rgb[3]
  end
  function frame:SetupColorPickerAndShow(info)
    self.info = info
    self.shown = true
  end
  function frame:IsShown()
    return self.shown == true
  end
  local saved = rawget(_G, "ColorPickerFrame")
  rawset(_G, "ColorPickerFrame", frame)
  local ok, err = pcall(fn, frame)
  rawset(_G, "ColorPickerFrame", saved)
  assert(ok, err)
end

return function()
  -- test_sits_under_edge_glow_with_window_animation_below
  do
    local result = create()
    local glow = FindUI.byLabel(result.frame, "Edge glow")
    local selector = FindUI.byLabel(result.frame, LABEL)
    assert(select(2, selector:GetPoint()) == glow, "anchored under Edge glow")
    assert(select(2, FindUI.byLabel(result.frame, "Window animation"):GetPoint()) == selector, "Window animation under it")
  end

  -- test_one_button_per_preset_then_custom
  do
    local result = create()
    local buttons = FindUI.selectorButtons(result.frame, LABEL)
    local keys = Theme.ListPresets()
    assert(#buttons == #keys + 1, "presets + Custom, got " .. #buttons)
    for i, key in ipairs(keys) do
      assert(buttons[i]._key == key, "button " .. i .. " is " .. key)
    end
    assert(buttons[#buttons]._key == "custom" and buttons[#buttons].label.text == "Custom", "Custom last")
  end

  -- test_nothing_saved_shows_the_active_preset
  do
    assert(selectedKey(create()) == Theme.GetPreset(), "the active preset is picked")
    assert(selectedKey(create({ edgeGlowColor = "plumber_warm" })) == "plumber_warm", "a saved preset is picked")
  end

  -- test_picking_a_preset_saves_it
  do
    local result, changes = create()
    local btn = FindUI.selectorButtons(result.frame, LABEL)[2]
    btn.scripts.OnClick(btn)
    assert(lastChange(changes, "edgeGlowColor").value == btn._key, "saves the preset key")
  end

  -- test_custom_previews_while_dragging_and_saves
  withPicker(function(picker)
    local result, changes = create()
    local custom = customButton(result)
    custom.scripts.OnClick(custom)
    local info = picker.info
    local accent = Theme.COLORS.accent
    assert(info and info.r == accent[1] and info.b == accent[3], "starts at the glow's current colour")
    picker.rgb = { 0.2, 0.4, 0.6 }
    info.swatchFunc()
    assert(lastChange(changes, "edgeGlowColor").value == "custom", "custom saved")
    local rgb = lastChange(changes, "edgeGlowCustom").value
    assert(rgb[1] == 0.2 and rgb[2] == 0.4 and rgb[3] == 0.6, "rgb saved as { r, g, b }")
    local c = custom.swatch.color
    assert(custom.swatch.shown ~= false and c[1] == 0.2 and c[3] == 0.6, "the swatch shows it")
    assert(selectedKey(result) == "custom", "Custom picked")
  end)

  -- test_cancel_restores_the_previous_choice
  withPicker(function(picker)
    local result, changes = create({ edgeGlowColor = "jade_dark" })
    local custom = customButton(result)
    custom.scripts.OnClick(custom)
    picker.rgb = { 0.9, 0.1, 0.1 }
    picker.info.swatchFunc()
    picker.info.cancelFunc({ r = 0, g = 0, b = 0 })
    assert(lastChange(changes, "edgeGlowColor").value == "jade_dark", "previous preset back")
    assert(lastChange(changes, "edgeGlowCustom").value == nil, "no custom colour, as before")
    assert(selectedKey(result) == "jade_dark", "selection back")
  end)

  -- test_custom_again_while_open_still_cancels_to_the_choice_before_the_picker
  withPicker(function(picker)
    local result, changes = create({ edgeGlowColor = "jade_dark" })
    local custom = customButton(result)
    custom.scripts.OnClick(custom)
    picker.rgb = { 0.9, 0.1, 0.1 }
    picker.info.swatchFunc()
    custom.scripts.OnClick(custom)
    picker.rgb = { 0.1, 0.9, 0.1 }
    picker.info.swatchFunc()
    picker.shown = false
    picker.info.cancelFunc({ r = 0, g = 0, b = 0 })
    assert(lastChange(changes, "edgeGlowColor").value == "jade_dark", "the pre-picker preset back")
    assert(lastChange(changes, "edgeGlowCustom").value == nil, "no custom colour, as before the picker")
  end)

  -- test_after_okay_a_new_picker_cancels_to_the_okayed_colour
  withPicker(function(picker)
    local result, changes = create({ edgeGlowColor = "jade_dark" })
    local custom = customButton(result)
    custom.scripts.OnClick(custom)
    picker.rgb = { 0.9, 0.1, 0.1 }
    picker.info.swatchFunc()
    picker.shown = false -- Okay closes it
    custom.scripts.OnClick(custom)
    picker.rgb = { 0.1, 0.9, 0.1 }
    picker.info.swatchFunc()
    picker.shown = false
    picker.info.cancelFunc({ r = 0, g = 0, b = 0 })
    assert(lastChange(changes, "edgeGlowColor").value == "custom", "the okayed custom stays")
    assert(lastChange(changes, "edgeGlowCustom").value[1] == 0.9, "the okayed colour back")
  end)

  -- test_an_invalid_saved_custom_colour_follows_the_active_preset
  withPicker(function(picker)
    local result = create({ edgeGlowColor = "custom", edgeGlowCustom = { "red", 1, 1 } })
    local custom = customButton(result)
    assert(custom.swatch.shown == false, "no swatch for a broken colour")
    assert(selectedKey(result) == Theme.GetPreset(), "the active preset shows")
    custom.scripts.OnClick(custom)
    assert(picker.info.r == Theme.COLORS.accent[1], "picker starts at the active accent")
  end)

  -- test_a_swatch_call_during_setup_still_cancels_back_to_nothing_saved
  withPicker(function(picker)
    function picker:SetupColorPickerAndShow(info)
      self.info = info
      self.rgb = { info.r, info.g, info.b }
      info.swatchFunc()
    end
    local result, changes = create()
    local custom = customButton(result)
    custom.scripts.OnClick(custom)
    picker.info.cancelFunc({ r = 0, g = 0, b = 0 })
    assert(lastChange(changes, "edgeGlowColor").value == nil and lastChange(changes, "edgeGlowCustom").value == nil, "both back to nil")
    assert(selectedKey(result) == Theme.GetPreset(), "the active preset shows again")
  end)

  -- test_saved_custom_colour_shows_on_the_swatch_and_seeds_the_picker
  withPicker(function(picker)
    local result = create({ edgeGlowColor = "custom", edgeGlowCustom = { 0.3, 0.2, 0.1 } })
    local custom = customButton(result)
    assert(custom.swatch.color[1] == 0.3 and custom.swatch.shown ~= false, "swatch painted")
    custom.scripts.OnClick(custom)
    assert(picker.info.r == 0.3 and picker.info.b == 0.1, "picker starts at the saved colour")
  end)

  -- test_reset_clears_both_keys
  do
    local result, changes = create({ edgeGlowColor = "custom", edgeGlowCustom = { 1, 1, 1 } })
    local reset = FindUI.byLabel(result.frame, "Reset to Defaults")
    reset.scripts.OnClick(reset)
    local color, custom = lastChange(changes, "edgeGlowColor"), lastChange(changes, "edgeGlowCustom")
    assert(color ~= nil and color.value == nil and custom ~= nil and custom.value == nil, "both cleared")
    assert(selectedKey(result) == Theme.GetPreset(), "the active preset shows again")
    assert(customButton(result).swatch.shown == false, "swatch hidden")
  end

  -- test_unset_follows_a_theme_preset_change
  do
    local result = create()
    local before = Theme.GetPreset()
    Theme.SetPreset("plumber_warm")
    result.refreshTheme(Theme)
    local picked = selectedKey(result)
    Theme.SetPreset(before)
    assert(picked == "plumber_warm", "the new preset shows, got " .. tostring(picked))
  end

  -- test_label_survives_a_language_refresh
  do
    local result = create()
    result.setLanguage()
    assert(FindUI.byLabel(result.frame, LABEL) ~= nil, "relabelled")
    assert(customButton(result).label.text == "Custom", "Custom relabelled")
  end
end
