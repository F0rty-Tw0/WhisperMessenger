local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local applyColorTexture = UIHelpers.applyColorTexture

local ButtonSelector = ns.MessengerWindowButtonSelector
  or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")

local AppearanceSettings = {}

local PADDING = Theme.CONTENT_PADDING
local SLIDER_WIDTH = 350
local SLIDER_HEIGHT = 16
local ROW_SPACING = 32
local LABEL_SPACING = 6

local FONT_OPTIONS = {
  { key = "default", label = "Default", tooltip = "Inherits your game font. Supports all languages." },
  { key = "system", label = "System", tooltip = "Arial Narrow. Clean sans-serif look." },
  { key = "morpheus", label = "Morpheus", tooltip = "Fantasy decorative font. Great for immersion." },
}

local OUTLINE_OPTIONS = {
  { key = "NONE", label = "None", tooltip = "No outline on text." },
  { key = "OUTLINE", label = "Outline", tooltip = "Thin outline for readability." },
  { key = "THICKOUTLINE", label = "Thick", tooltip = "Thick outline for maximum contrast." },
}

local function buildFontColorOptions()
  local presets = Fonts.ListFontColorPresets and Fonts.ListFontColorPresets() or {}
  local options = {}
  for _, preset in ipairs(presets) do
    local tooltip = "Use theme colors"
    if preset.rgba then
      tooltip = preset.label .. " text color"
    end
    options[#options + 1] = { key = preset.key, label = preset.label, tooltip = tooltip }
  end
  return options
end

local PRESET_LABELS = {
  wow_default = { label = "Midnight", tooltip = "Default colors and contrasts." },
  elvui_dark = { label = "Shadowlands", tooltip = "Dark UI style inspired by ElvUI." },
  plumber_warm = { label = "Draenor", tooltip = "Warm tones with softer contrast." },
}

local function buildThemePresetOptions()
  local keys = Theme.ListPresets and Theme.ListPresets() or { "wow_default", "elvui_dark", "plumber_warm" }
  local options = {}
  for _, key in ipairs(keys) do
    local meta = PRESET_LABELS[key] or { label = key, tooltip = "Theme preset" }
    options[#options + 1] = { key = key, label = meta.label, tooltip = meta.tooltip }
  end
  return options
end

local BUBBLE_COLOR_LABELS = {
  default = { label = "Default", tooltip = "Uses your theme's bubble colors." },
  shadow = { label = "Shadow", tooltip = "Muted dark tones." },
  ember = { label = "Ember", tooltip = "Warm earthy tones." },
  arcane = { label = "Arcane", tooltip = "Purple arcane-infused tones." },
  frost = { label = "Frost", tooltip = "Cool steel-blue tones." },
  fel = { label = "Fel", tooltip = "Eerie fel-green tones." },
}

local function buildBubbleColorOptions()
  local keys = Theme.ListBubblePresets and Theme.ListBubblePresets() or { "default" }
  local options = {}
  for _, key in ipairs(keys) do
    local meta = BUBBLE_COLOR_LABELS[key] or { label = key, tooltip = "Bubble color preset" }
    options[#options + 1] = { key = key, label = meta.label, tooltip = meta.tooltip }
  end
  return options
end

local DEFAULTS = {
  windowOpacityInactive = 0.72,
  windowOpacityActive = 1.0,
  fontFamily = "default",
  fontSize = 12,
  fontOutline = "NONE",
  fontColor = "default",
  bubbleColorPreset = "default",
  themePreset = Theme.DEFAULT_PRESET or "wow_default",
}

local function createSliderRow(factory, parent, label, min, max, step, initial, formatFn, onChange)
  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(SLIDER_WIDTH, SLIDER_HEIGHT + 20)

  local labelFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText(label)
  UIHelpers.setTextColor(labelFs, Theme.COLORS.text_primary)

  local valueFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  valueFs:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
  UIHelpers.setTextColor(valueFs, Theme.COLORS.text_secondary)

  local slider = factory.CreateFrame("Slider", nil, row)
  slider:SetSize(SLIDER_WIDTH, SLIDER_HEIGHT)
  slider:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -LABEL_SPACING)
  if slider.SetOrientation then
    slider:SetOrientation("HORIZONTAL")
  end
  slider:SetMinMaxValues(min, max)
  slider:SetValueStep(step)
  if slider.SetObeyStepOnDrag then
    slider:SetObeyStepOnDrag(true)
  end

  local bg = slider:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(slider)
  applyColorTexture(bg, Theme.COLORS.option_button_bg)

  if slider.SetThumbTexture then
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  end

  local minLabel = slider:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
  minLabel:SetText(formatFn and formatFn(min) or tostring(min))
  UIHelpers.setTextColor(minLabel, Theme.COLORS.text_secondary)

  local maxLabel = slider:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
  maxLabel:SetText(formatFn and formatFn(max) or tostring(max))
  UIHelpers.setTextColor(maxLabel, Theme.COLORS.text_secondary)

  slider:SetValue(initial)
  valueFs:SetText(formatFn and formatFn(initial) or tostring(initial))

  slider:SetScript("OnValueChanged", function(_self, value)
    local stepped = math.floor(value / step + 0.5) * step
    valueFs:SetText(formatFn and formatFn(stepped) or tostring(stepped))
    if onChange then
      onChange(stepped)
    end
  end)

  return {
    row = row,
    label = labelFs,
    value = valueFs,
    slider = slider,
    sliderBg = bg,
    minLabel = minLabel,
    maxLabel = maxLabel,
    applyTheme = function(activeTheme)
      UIHelpers.setTextColor(labelFs, activeTheme.COLORS.text_primary)
      UIHelpers.setTextColor(valueFs, activeTheme.COLORS.text_secondary)
      applyColorTexture(bg, activeTheme.COLORS.option_button_bg)
      UIHelpers.setTextColor(minLabel, activeTheme.COLORS.text_secondary)
      UIHelpers.setTextColor(maxLabel, activeTheme.COLORS.text_secondary)
    end,
  }
end

local function createButtonSelector(factory, parent, labelText, optionsList, fallbackKey, initial, colors, onChange)
  return ButtonSelector.Create(factory, parent, {
    labelText = labelText,
    optionsList = optionsList,
    fallbackKey = fallbackKey,
    initial = initial,
    colors = colors,
    onChange = onChange,
    rowWidth = SLIDER_WIDTH,
    labelSpacing = LABEL_SPACING,
  })
end

local function pctFormat(v)
  return tostring(math.floor(v * 100 + 0.5)) .. "%"
end

function AppearanceSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local title = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  title:SetText("Appearance")
  UIHelpers.setTextColor(title, Theme.COLORS.text_primary)

  local hint = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  hint:SetText("Customize theme presets, fonts, and window opacity.")
  if hint.SetWordWrap then
    hint:SetWordWrap(true)
  end
  if hint.SetJustifyH then
    hint:SetJustifyH("LEFT")
  end
  if hint.SetWidth then
    hint:SetWidth(SLIDER_WIDTH)
  end
  UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)

  local function selectorColorsFor(activeTheme)
    return {
      bg = activeTheme.COLORS.option_button_bg,
      bgHover = activeTheme.COLORS.option_button_hover,
      bgActive = activeTheme.COLORS.option_button_active or activeTheme.COLORS.bg_contact_selected,
      text = activeTheme.COLORS.option_button_text,
      textHover = activeTheme.COLORS.option_button_text_hover,
      textActive = activeTheme.COLORS.option_button_text_active or activeTheme.COLORS.text_primary,
    }
  end
  local selectorColors = selectorColorsFor(Theme)
  local themePresetOptions = buildThemePresetOptions()
  local themePresetSelector = createButtonSelector(
    factory,
    frame,
    "Theme Preset",
    themePresetOptions,
    DEFAULTS.themePreset,
    config.themePreset or DEFAULTS.themePreset,
    selectorColors,
    function(value)
      onChange("themePreset", value)
    end
  )
  themePresetSelector.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -ROW_SPACING)

  local fontSelector = createButtonSelector(
    factory,
    frame,
    "Font Family",
    FONT_OPTIONS,
    DEFAULTS.fontFamily,
    config.fontFamily or DEFAULTS.fontFamily,
    selectorColors,
    function(value)
      onChange("fontFamily", value)
    end
  )
  fontSelector.row:SetPoint("TOPLEFT", themePresetSelector.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local function pxFormat(v)
    return tostring(math.floor(v + 0.5)) .. "px"
  end

  local fontSizeRow = createSliderRow(
    factory,
    frame,
    "Font Size",
    9,
    17,
    1,
    config.fontSize or DEFAULTS.fontSize,
    pxFormat,
    function(value)
      onChange("fontSize", value)
    end
  )
  fontSizeRow.row:SetPoint("TOPLEFT", fontSelector.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local fontOutlineSelector = createButtonSelector(
    factory,
    frame,
    "Font Outline",
    OUTLINE_OPTIONS,
    DEFAULTS.fontOutline,
    config.fontOutline or DEFAULTS.fontOutline,
    selectorColors,
    function(value)
      onChange("fontOutline", value)
    end
  )
  fontOutlineSelector.row:SetPoint("TOPLEFT", fontSizeRow.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local fontColorOptions = buildFontColorOptions()
  local fontColorSelector = ButtonSelector.Create(factory, frame, {
    labelText = "Chat Font Color",
    optionsList = fontColorOptions,
    fallbackKey = DEFAULTS.fontColor,
    initial = config.fontColor or DEFAULTS.fontColor,
    colors = selectorColors,
    onChange = function(value)
      onChange("fontColor", value)
    end,
    rowWidth = SLIDER_WIDTH,
    labelSpacing = LABEL_SPACING,
    maxPerRow = 3,
  })
  fontColorSelector.row:SetPoint("TOPLEFT", fontOutlineSelector.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local bubbleColorOptions = buildBubbleColorOptions()
  local bubbleColorSelector = ButtonSelector.Create(factory, frame, {
    labelText = "Bubble Colors",
    optionsList = bubbleColorOptions,
    fallbackKey = DEFAULTS.bubbleColorPreset,
    initial = config.bubbleColorPreset or DEFAULTS.bubbleColorPreset,
    colors = selectorColors,
    onChange = function(value)
      onChange("bubbleColorPreset", value)
    end,
    rowWidth = SLIDER_WIDTH,
    labelSpacing = LABEL_SPACING,
    maxPerRow = 3,
  })
  bubbleColorSelector.row:SetPoint("TOPLEFT", fontColorSelector.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local opacityInactiveRow = createSliderRow(
    factory,
    frame,
    "Window Opacity (Inactive)",
    0.3,
    1.0,
    0.05,
    config.windowOpacityInactive or DEFAULTS.windowOpacityInactive,
    pctFormat,
    function(value)
      onChange("windowOpacityInactive", value)
    end
  )
  opacityInactiveRow.row:SetPoint("TOPLEFT", bubbleColorSelector.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local opacityActiveRow = createSliderRow(
    factory,
    frame,
    "Window Opacity (Active)",
    0.5,
    1.0,
    0.05,
    config.windowOpacityActive or DEFAULTS.windowOpacityActive,
    pctFormat,
    function(value)
      onChange("windowOpacityActive", value)
    end
  )
  opacityActiveRow.row:SetPoint("TOPLEFT", opacityInactiveRow.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  -- Reset button
  local function optionButtonColorsFor(activeTheme)
    return {
      bg = activeTheme.COLORS.option_button_bg,
      bgHover = activeTheme.COLORS.option_button_hover,
      text = activeTheme.COLORS.option_button_text,
      textHover = activeTheme.COLORS.option_button_text_hover,
    }
  end
  local normalColors = optionButtonColorsFor(Theme)
  local resetButton = UIHelpers.createOptionButton(
    factory,
    frame,
    "Reset to Defaults",
    normalColors,
    { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = SLIDER_WIDTH }
  )
  resetButton:SetPoint("TOPLEFT", opacityActiveRow.row, "BOTTOMLEFT", 0, -ROW_SPACING)
  resetButton:SetScript("OnClick", function()
    opacityInactiveRow.slider:SetValue(DEFAULTS.windowOpacityInactive)
    opacityActiveRow.slider:SetValue(DEFAULTS.windowOpacityActive)
    themePresetSelector.setSelected(DEFAULTS.themePreset)
    onChange("themePreset", DEFAULTS.themePreset)
    fontSelector.setSelected(DEFAULTS.fontFamily)
    onChange("fontFamily", DEFAULTS.fontFamily)
    fontSizeRow.slider:SetValue(DEFAULTS.fontSize)
    onChange("fontSize", DEFAULTS.fontSize)
    fontOutlineSelector.setSelected(DEFAULTS.fontOutline)
    onChange("fontOutline", DEFAULTS.fontOutline)
    fontColorSelector.setSelected(DEFAULTS.fontColor)
    onChange("fontColor", DEFAULTS.fontColor)
    bubbleColorSelector.setSelected(DEFAULTS.bubbleColorPreset)
    onChange("bubbleColorPreset", DEFAULTS.bubbleColorPreset)
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    UIHelpers.setTextColor(title, activeTheme.COLORS.text_primary)
    UIHelpers.setTextColor(hint, activeTheme.COLORS.text_secondary)

    local activeSelectorColors = selectorColorsFor(activeTheme)
    themePresetSelector.applyTheme(activeTheme, activeSelectorColors)
    fontSelector.applyTheme(activeTheme, activeSelectorColors)
    fontOutlineSelector.applyTheme(activeTheme, activeSelectorColors)
    fontColorSelector.applyTheme(activeTheme, activeSelectorColors)
    bubbleColorSelector.applyTheme(activeTheme, activeSelectorColors)

    fontSizeRow.applyTheme(activeTheme)
    opacityInactiveRow.applyTheme(activeTheme)
    opacityActiveRow.applyTheme(activeTheme)

    if resetButton.applyThemeColors then
      resetButton.applyThemeColors(optionButtonColorsFor(activeTheme))
    end
  end

  refreshTheme(Theme)

  return {
    frame = frame,
    themePresetSelector = themePresetSelector,
    fontSelector = fontSelector,
    fontSizeSlider = fontSizeRow.slider,
    fontOutlineSelector = fontOutlineSelector,
    fontColorSelector = fontColorSelector,
    bubbleColorSelector = bubbleColorSelector,
    opacityInactiveSlider = opacityInactiveRow.slider,
    opacityActiveSlider = opacityActiveRow.slider,
    resetButton = resetButton,
    refreshTheme = refreshTheme,
  }
end

ns.AppearanceSettings = AppearanceSettings
return AppearanceSettings
