local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")

local ButtonSelector = ns.MessengerWindowButtonSelector
  or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")

local AppearanceSettings = {}

local PADDING = Theme.CONTENT_PADDING

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

local PRESET_LABELS = {
  wow_default = { label = "Midnight", tooltip = "Default colors and contrasts." },
  elvui_dark = { label = "Shadowlands", tooltip = "Dark UI style inspired by ElvUI." },
  plumber_warm = { label = "Draenor", tooltip = "Warm tones with softer contrast." },
  wow_native = { label = "Azeroth", tooltip = "Native WoW colors with gold accents." },
}

local BUBBLE_COLOR_LABELS = {
  default = { label = "Default", tooltip = "Uses your theme's bubble colors." },
  shadow = { label = "Shadow", tooltip = "Muted dark tones." },
  ember = { label = "Ember", tooltip = "Warm earthy tones." },
  arcane = { label = "Arcane", tooltip = "Purple arcane-infused tones." },
  frost = { label = "Frost", tooltip = "Cool steel-blue tones." },
  fel = { label = "Fel", tooltip = "Eerie fel-green tones." },
}

local function buildFontColorOptions()
  local presets = Fonts.ListFontColorPresets and Fonts.ListFontColorPresets() or {}
  local options = {}
  for _, p in ipairs(presets) do
    options[#options + 1] = {
      key = p.key,
      label = p.label,
      tooltip = p.rgba and (p.label .. " text color") or "Use theme colors",
    }
  end
  return options
end

local function buildThemePresetOptions()
  local keys = Theme.ListPresets and Theme.ListPresets() or { "wow_default", "elvui_dark", "plumber_warm" }
  return SettingsControls.ProjectLabeledOptions(keys, PRESET_LABELS, function(key)
    return { label = key, tooltip = "Theme preset" }
  end)
end

local function buildBubbleColorOptions()
  local keys = Theme.ListBubblePresets and Theme.ListBubblePresets() or { "default" }
  return SettingsControls.ProjectLabeledOptions(keys, BUBBLE_COLOR_LABELS, function(key)
    return { label = key, tooltip = "Bubble color preset" }
  end)
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
  nativeChrome = false,
}

local function pctFormat(v)
  return tostring(math.floor(v * 100 + 0.5)) .. "%"
end
local function pxFormat(v)
  return tostring(math.floor(v + 0.5)) .. "px"
end

function AppearanceSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function() end

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
    hint:SetWidth(Theme.LAYOUT.SETTINGS_CONTROL_WIDTH)
  end
  UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)

  local selectorColors = SettingsControls.SelectorColors(Theme)
  local gap = -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING

  local function sel(labelText, opts, fallback, initial, onCh, extra)
    local spec = {
      labelText = labelText,
      optionsList = opts,
      fallbackKey = fallback,
      initial = initial,
      colors = selectorColors,
      onChange = onCh,
      rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
      labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
    }
    if extra then
      for k, v in pairs(extra) do
        spec[k] = v
      end
    end
    return ButtonSelector.Create(factory, frame, spec)
  end

  local function slider(label, min, max, step, initial, fmt, onCh)
    return SettingsControls.CreateSliderRow(factory, frame, {
      label = label,
      min = min,
      max = max,
      step = step,
      initial = initial,
      formatFn = fmt,
      onChange = onCh,
    })
  end

  local nativeChromeToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Native WoW HUD",
    config.nativeChrome == true,
    SettingsControls.ToggleColors(Theme),
    { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 },
    function(v)
      onChange("nativeChrome", v)
    end,
    {
      "Native WoW HUD",
      "Replaces the messenger window border, title bar, and close button with Blizzard's default UI style. Requires /reload to apply.",
    }
  )
  nativeChromeToggle.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, gap)

  local themePresetSelector = sel(
    "Theme Preset",
    buildThemePresetOptions(),
    DEFAULTS.themePreset,
    config.themePreset or DEFAULTS.themePreset,
    function(v)
      onChange("themePreset", v)
    end
  )
  themePresetSelector.row:SetPoint("TOPLEFT", nativeChromeToggle.row, "BOTTOMLEFT", 0, gap)

  local fontSelector = sel(
    "Font Family",
    FONT_OPTIONS,
    DEFAULTS.fontFamily,
    config.fontFamily or DEFAULTS.fontFamily,
    function(v)
      onChange("fontFamily", v)
    end
  )
  fontSelector.row:SetPoint("TOPLEFT", themePresetSelector.row, "BOTTOMLEFT", 0, gap)

  local fontSizeRow = slider("Font Size", 9, 17, 1, config.fontSize or DEFAULTS.fontSize, pxFormat, function(v)
    onChange("fontSize", v)
  end)
  fontSizeRow.row:SetPoint("TOPLEFT", fontSelector.row, "BOTTOMLEFT", 0, gap)

  local fontOutlineSelector = sel(
    "Font Outline",
    OUTLINE_OPTIONS,
    DEFAULTS.fontOutline,
    config.fontOutline or DEFAULTS.fontOutline,
    function(v)
      onChange("fontOutline", v)
    end
  )
  fontOutlineSelector.row:SetPoint("TOPLEFT", fontSizeRow.row, "BOTTOMLEFT", 0, gap)

  local fontColorSelector = sel(
    "Chat Font Color",
    buildFontColorOptions(),
    DEFAULTS.fontColor,
    config.fontColor or DEFAULTS.fontColor,
    function(v)
      onChange("fontColor", v)
    end,
    { maxPerRow = 3 }
  )
  fontColorSelector.row:SetPoint("TOPLEFT", fontOutlineSelector.row, "BOTTOMLEFT", 0, gap)

  local bubbleColorSelector = sel(
    "Bubble Colors",
    buildBubbleColorOptions(),
    DEFAULTS.bubbleColorPreset,
    config.bubbleColorPreset or DEFAULTS.bubbleColorPreset,
    function(v)
      onChange("bubbleColorPreset", v)
    end,
    { maxPerRow = 3 }
  )
  bubbleColorSelector.row:SetPoint("TOPLEFT", fontColorSelector.row, "BOTTOMLEFT", 0, gap)

  local opacityInactiveRow = slider(
    "Window Opacity (Inactive)",
    0.3,
    1.0,
    0.05,
    config.windowOpacityInactive or DEFAULTS.windowOpacityInactive,
    pctFormat,
    function(v)
      onChange("windowOpacityInactive", v)
    end
  )
  opacityInactiveRow.row:SetPoint("TOPLEFT", bubbleColorSelector.row, "BOTTOMLEFT", 0, gap)

  local opacityActiveRow = slider(
    "Window Opacity (Active)",
    0.5,
    1.0,
    0.05,
    config.windowOpacityActive or DEFAULTS.windowOpacityActive,
    pctFormat,
    function(v)
      onChange("windowOpacityActive", v)
    end
  )
  opacityActiveRow.row:SetPoint("TOPLEFT", opacityInactiveRow.row, "BOTTOMLEFT", 0, gap)

  local resetButton = UIHelpers.createOptionButton(
    factory,
    frame,
    "Reset to Defaults",
    SettingsControls.OptionButtonColors(Theme),
    { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH }
  )
  resetButton:SetPoint("TOPLEFT", opacityActiveRow.row, "BOTTOMLEFT", 0, gap)
  resetButton:SetScript("OnClick", function()
    opacityInactiveRow.slider:SetValue(DEFAULTS.windowOpacityInactive)
    opacityActiveRow.slider:SetValue(DEFAULTS.windowOpacityActive)
    nativeChromeToggle.setValue(DEFAULTS.nativeChrome)
    onChange("nativeChrome", DEFAULTS.nativeChrome)
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

    local activeSelectorColors = SettingsControls.SelectorColors(activeTheme)
    nativeChromeToggle.applyThemeColors(SettingsControls.ToggleColors(activeTheme))
    themePresetSelector.applyTheme(activeTheme, activeSelectorColors)
    fontSelector.applyTheme(activeTheme, activeSelectorColors)
    fontOutlineSelector.applyTheme(activeTheme, activeSelectorColors)
    fontColorSelector.applyTheme(activeTheme, activeSelectorColors)
    bubbleColorSelector.applyTheme(activeTheme, activeSelectorColors)
    fontSizeRow.applyTheme(activeTheme)
    opacityInactiveRow.applyTheme(activeTheme)
    opacityActiveRow.applyTheme(activeTheme)
    if resetButton.applyThemeColors then
      resetButton.applyThemeColors(SettingsControls.OptionButtonColors(activeTheme))
    end
  end

  refreshTheme(Theme)

  local function refreshLayout(width)
    if type(width) ~= "number" or width <= 0 then
      return
    end
    local maxWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
    local effective = math.min(maxWidth, math.max(160, math.floor(width)))
    if hint.SetWidth then
      hint:SetWidth(effective)
    end
    nativeChromeToggle.setWidth(effective)
    themePresetSelector.setWidth(effective)
    fontSelector.setWidth(effective)
    fontSizeRow.setWidth(effective)
    fontOutlineSelector.setWidth(effective)
    fontColorSelector.setWidth(effective)
    bubbleColorSelector.setWidth(effective)
    opacityInactiveRow.setWidth(effective)
    opacityActiveRow.setWidth(effective)
    if resetButton.setWidth then
      resetButton.setWidth(effective)
    end
  end

  return {
    frame = frame,
    refreshLayout = refreshLayout,
    nativeChromeToggle = nativeChromeToggle,
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
