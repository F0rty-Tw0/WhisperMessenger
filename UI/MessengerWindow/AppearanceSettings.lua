local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")

local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local Options = ns.AppearanceSettingsOptions or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.Options")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

local AppearanceSettings = {}

local PADDING = Theme.CONTENT_PADDING
local function text(key)
  return Localization.Text(key)
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

  local header = SettingsControls.CreateHeader(frame, {
    title = text("Appearance"),
    hint = text("Customize theme presets, fonts, and window opacity."),
  })
  local hint = header.hint

  local selectorColors = SettingsControls.SelectorColors(Theme)
  local gap = -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING
  local panel = SettingsControls.NewPanelRegistry()

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

  local nativeChromeToggle = panel:bind(
    UIHelpers.createToggleRow(factory, frame, text("Native WoW HUD"), config.nativeChrome == true, SettingsControls.ToggleColors(Theme), {
      width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
      height = 24,
    }, function(v)
      onChange("nativeChrome", v)
    end, {
      text("Native WoW HUD"),
      text("Replaces the messenger window border, title bar, and close button with Blizzard's default UI style. Requires /reload to apply."),
    }),
    { type = "toggle", key = "nativeChrome", default = DEFAULTS.nativeChrome }
  )
  nativeChromeToggle.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, gap)

  local themePresetSelector = panel:bind(
    sel(text("Theme Preset"), Options.BuildThemePresetOptions(), DEFAULTS.themePreset, config.themePreset or DEFAULTS.themePreset, function(v)
      onChange("themePreset", v)
    end),
    { type = "selector", key = "themePreset", default = DEFAULTS.themePreset }
  )
  themePresetSelector.row:SetPoint("TOPLEFT", nativeChromeToggle.row, "BOTTOMLEFT", 0, gap)

  local fontSelector = panel:bind(
    sel(text("Font Family"), Options.BuildFontOptions(), DEFAULTS.fontFamily, config.fontFamily or DEFAULTS.fontFamily, function(v)
      onChange("fontFamily", v)
    end),
    { type = "selector", key = "fontFamily", default = DEFAULTS.fontFamily }
  )
  fontSelector.row:SetPoint("TOPLEFT", themePresetSelector.row, "BOTTOMLEFT", 0, gap)

  local fontSizeRow = panel:bind(
    slider(text("Font Size"), 9, 17, 1, config.fontSize or DEFAULTS.fontSize, pxFormat, function(v)
      onChange("fontSize", v)
    end),
    { type = "slider", key = "fontSize", default = DEFAULTS.fontSize }
  )
  fontSizeRow.row:SetPoint("TOPLEFT", fontSelector.row, "BOTTOMLEFT", 0, gap)

  local fontOutlineSelector = panel:bind(
    sel(text("Font Outline"), Options.BuildOutlineOptions(), DEFAULTS.fontOutline, config.fontOutline or DEFAULTS.fontOutline, function(v)
      onChange("fontOutline", v)
    end),
    { type = "selector", key = "fontOutline", default = DEFAULTS.fontOutline }
  )
  fontOutlineSelector.row:SetPoint("TOPLEFT", fontSizeRow.row, "BOTTOMLEFT", 0, gap)

  local fontColorSelector = panel:bind(
    sel(text("Chat Font Color"), Options.BuildFontColorOptions(), DEFAULTS.fontColor, config.fontColor or DEFAULTS.fontColor, function(v)
      onChange("fontColor", v)
    end, { maxPerRow = 3 }),
    { type = "selector", key = "fontColor", default = DEFAULTS.fontColor }
  )
  fontColorSelector.row:SetPoint("TOPLEFT", fontOutlineSelector.row, "BOTTOMLEFT", 0, gap)

  local bubbleColorSelector = panel:bind(
    sel(
      text("Bubble Colors"),
      Options.BuildBubbleColorOptions(),
      DEFAULTS.bubbleColorPreset,
      config.bubbleColorPreset or DEFAULTS.bubbleColorPreset,
      function(v)
        onChange("bubbleColorPreset", v)
      end,
      { maxPerRow = 3 }
    ),
    { type = "selector", key = "bubbleColorPreset", default = DEFAULTS.bubbleColorPreset }
  )
  bubbleColorSelector.row:SetPoint("TOPLEFT", fontColorSelector.row, "BOTTOMLEFT", 0, gap)

  local opacityInactiveRow = panel:bind(
    slider(text("Window Opacity (Inactive)"), 0.3, 1.0, 0.05, config.windowOpacityInactive or DEFAULTS.windowOpacityInactive, pctFormat, function(v)
      onChange("windowOpacityInactive", v)
    end),
    { type = "slider", key = "windowOpacityInactive", default = DEFAULTS.windowOpacityInactive }
  )
  opacityInactiveRow.row:SetPoint("TOPLEFT", bubbleColorSelector.row, "BOTTOMLEFT", 0, gap)

  local opacityActiveRow = panel:bind(
    slider(text("Window Opacity (Active)"), 0.5, 1.0, 0.05, config.windowOpacityActive or DEFAULTS.windowOpacityActive, pctFormat, function(v)
      onChange("windowOpacityActive", v)
    end),
    { type = "slider", key = "windowOpacityActive", default = DEFAULTS.windowOpacityActive }
  )
  opacityActiveRow.row:SetPoint("TOPLEFT", opacityInactiveRow.row, "BOTTOMLEFT", 0, gap)

  local resetButton = panel:bind(
    UIHelpers.createOptionButton(
      factory,
      frame,
      text("Reset to Defaults"),
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH }
    ),
    { type = "optionButton" }
  )
  resetButton:SetPoint("TOPLEFT", opacityActiveRow.row, "BOTTOMLEFT", 0, gap)
  resetButton:SetScript("OnClick", function()
    panel:reset(onChange)
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)
  frame._wmBottomMarker = bottomSpacer

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
    panel:refreshTheme(activeTheme)
  end

  refreshTheme(Theme)

  local function setLanguage()
    header.title:SetText(text("Appearance"))
    header.hint:SetText(text("Customize theme presets, fonts, and window opacity."))
    nativeChromeToggle.label:SetText(text("Native WoW HUD"))
    themePresetSelector.label:SetText(text("Theme Preset"))
    themePresetSelector.setOptionsList(Options.BuildThemePresetOptions())
    fontSelector.label:SetText(text("Font Family"))
    fontSelector.setOptionsList(Options.BuildFontOptions())
    fontSizeRow.label:SetText(text("Font Size"))
    fontOutlineSelector.label:SetText(text("Font Outline"))
    fontOutlineSelector.setOptionsList(Options.BuildOutlineOptions())
    fontColorSelector.label:SetText(text("Chat Font Color"))
    fontColorSelector.setOptionsList(Options.BuildFontColorOptions())
    bubbleColorSelector.label:SetText(text("Bubble Colors"))
    bubbleColorSelector.setOptionsList(Options.BuildBubbleColorOptions())
    opacityInactiveRow.label:SetText(text("Window Opacity (Inactive)"))
    opacityActiveRow.label:SetText(text("Window Opacity (Active)"))
    resetButton.label:SetText(text("Reset to Defaults"))
  end

  local function refreshLayout(width)
    if type(width) ~= "number" or width <= 0 then
      return
    end
    local maxWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
    local effective = math.min(maxWidth, math.max(160, math.floor(width)))
    header.refreshLayout(effective)
    panel:refreshLayout(effective)
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
    setLanguage = setLanguage,
  }
end

ns.AppearanceSettings = AppearanceSettings
return AppearanceSettings
