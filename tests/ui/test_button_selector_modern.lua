local FakeUI = require("tests.helpers.fake_ui")
local Theme = require("WhisperMessenger.UI.Theme")
local ButtonSelector = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local SelectorSkin = require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.SelectorSkin")

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

local PRESETS = {
  { key = "wow_default", label = "Midnight" },
  { key = "elvui_dark", label = "Shadowlands" },
  { key = "plumber_warm", label = "Draenor" },
  { key = "jade_dark", label = "Pandaria" },
  { key = "wow_native", label = "Azeroth" },
}

local function newSelector(factory, extra)
  local parent = factory.CreateFrame("Frame", nil, nil)
  local spec = {
    labelText = "Theme Preset",
    optionsList = PRESETS,
    fallbackKey = "wow_default",
    initial = "wow_default",
    rowWidth = 350,
    buttonSpacing = 8,
  }
  for k, v in pairs(extra or {}) do
    spec[k] = v
  end
  return ButtonSelector.Create(factory, parent, spec)
end

local function assertLabelsFit(selector, context)
  for i, btn in ipairs(selector.buttons) do
    local need = btn.label:GetStringWidth() + 2 * SelectorSkin.PADDING_X
    assert(btn.width >= need, context .. ": button " .. i .. " width " .. tostring(btn.width) .. " < label+padding " .. need)
  end
end

return function()
  local previousPreset = Theme.GetPreset()
  local factory = FakeUI.NewFactory()

  Theme.SetPreset("wow_default")
  local preset = "wow_default"

  -- test_long_labels_keep_horizontal_padding (the Shadowlands bug)
  do
    local selector = newSelector(factory)
    assertLabelsFit(selector, preset)
    assert(selector.buttons[1].width == selector.buttons[2].width, preset .. ": first row buttons share one width")
    assert(selector.buttons[4].point[1] == "TOPLEFT", preset .. ": overflow wraps to a new row")
  end

  -- test_fixed_width_grows_to_fit_label
  do
    local selector = newSelector(factory, { buttonWidth = 40 })
    assertLabelsFit(selector, preset .. " fixed")
  end

  -- test_relabel_refits_buttons
  do
    local selector = newSelector(factory)
    selector.setOptionsList({
      { key = "wow_default", label = "Mitternachtsschatten" },
      { key = "elvui_dark", label = "B" },
      { key = "plumber_warm", label = "C" },
      { key = "jade_dark", label = "D" },
      { key = "wow_native", label = "E" },
    })
    assertLabelsFit(selector, preset .. " relabel")
  end

  -- test_modern_selected_is_accent_tint_with_underline
  do
    local selector = newSelector(factory)
    local selected = selector.buttons[1]
    assert(colorsMatch(selected.bg.color, Theme.COLORS.option_button_active), "selected fill is the accent tint")
    assert(selected.underline.shown == true, "selected shows the accent underline")
    assert(colorsMatch(selected.underline.color, Theme.COLORS.accent_bar), "underline uses accent_bar")
    assert(colorsMatch(selected.label.textColor, Theme.COLORS.text_primary), "selected text is primary")
    local other = selector.buttons[2]
    assert(other.underline.shown ~= true, "unselected has no underline")
    assert(colorsMatch(other.bg.color, Theme.COLORS.option_button_bg), "unselected sits on the subtle surface")
    assert(colorsMatch(other.label.textColor, Theme.COLORS.text_secondary), "unselected text is secondary")
  end

  -- test_modern_hover_is_faint_wash
  do
    local selector = newSelector(factory)
    local other = selector.buttons[2]
    other.scripts.OnEnter(other)
    assert(other.hover.shown == true, "hover wash shown")
    assert(colorsMatch(other.label.textColor, Theme.COLORS.text_primary), "hover brightens text")
    other.scripts.OnLeave(other)
    assert(other.hover.shown ~= true, "wash hidden on leave")
    assert(colorsMatch(other.label.textColor, Theme.COLORS.text_secondary), "leave restores text")
  end

  -- test_modern_click_moves_underline
  do
    local selector = newSelector(factory)
    selector.buttons[2].scripts.OnClick(selector.buttons[2])
    assert(selector.buttons[2].underline.shown == true, "clicked button gets the underline")
    assert(selector.buttons[1].underline.shown ~= true, "previous selection loses it")
  end

  Theme.SetPreset(previousPreset)
  print("  All modern button selector tests passed")
end
