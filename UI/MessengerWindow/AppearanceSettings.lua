local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

local AppearanceSettings = {}

local PADDING = Theme.CONTENT_PADDING
local SLIDER_WIDTH = 280
local SLIDER_HEIGHT = 16
local ROW_SPACING = 32
local LABEL_SPACING = 6

local FONT_OPTIONS = {
  { key = "default", label = "Default", tooltip = "Inherits your game font. Supports all languages." },
  { key = "system", label = "System", tooltip = "Arial Narrow. Clean sans-serif look." },
}

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

local DEFAULTS = {
  windowOpacityInactive = 0.72,
  windowOpacityActive = 1.0,
  fontFamily = "default",
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
  local BUTTON_WIDTH = 86
  local BUTTON_HEIGHT = 26
  local BUTTON_SPACING = 8

  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(SLIDER_WIDTH, BUTTON_HEIGHT + 20)

  local labelFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText(labelText)
  UIHelpers.setTextColor(labelFs, Theme.COLORS.text_primary)

  local function hasOptionKey(candidate)
    for _, opt in ipairs(optionsList) do
      if opt.key == candidate then
        return true
      end
    end
    return false
  end

  local buttons = {}
  local selected = hasOptionKey(initial) and initial or fallbackKey
  local palette = {
    bg = colors.bg or Theme.COLORS.option_button_bg,
    bgHover = colors.bgHover or Theme.COLORS.option_button_hover,
    bgActive = colors.bgActive or Theme.COLORS.option_button_active or Theme.COLORS.option_button_hover,
    text = colors.text or Theme.COLORS.option_button_text,
    textHover = colors.textHover or Theme.COLORS.option_button_text_hover,
    textActive = colors.textActive or Theme.COLORS.option_button_text_active or Theme.COLORS.text_primary,
  }

  local function paintButton(entry, isHovered)
    if entry._key == selected then
      entry._selected = true
      applyColorTexture(entry.bg, palette.bgActive)
      UIHelpers.setTextColor(entry.label, palette.textActive)
      return
    end

    entry._selected = false
    if isHovered then
      applyColorTexture(entry.bg, palette.bgHover)
      UIHelpers.setTextColor(entry.label, palette.textHover)
      return
    end

    applyColorTexture(entry.bg, palette.bg)
    UIHelpers.setTextColor(entry.label, palette.text)
  end

  local function repaintButtons()
    for _, entry in ipairs(buttons) do
      paintButton(entry, entry._hovered == true)
    end
  end

  local function updateSelection(nextSelected)
    selected = hasOptionKey(nextSelected) and nextSelected or fallbackKey
    repaintButtons()
  end

  for i, opt in ipairs(optionsList) do
    local btn = factory.CreateFrame("Button", nil, row)
    btn:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)

    if i == 1 then
      btn:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -LABEL_SPACING)
    else
      btn:SetPoint("LEFT", buttons[i - 1], "RIGHT", BUTTON_SPACING, 0)
    end

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(btn)

    local btnLabel = btn:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
    btnLabel:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btnLabel:SetText(opt.label)

    btn._key = opt.key
    btn._selected = false
    btn._hovered = false
    btn.bg = bg
    btn.label = btnLabel

    btn:SetScript("OnClick", function()
      updateSelection(opt.key)
      if onChange then
        onChange(opt.key)
      end
    end)

    btn:SetScript("OnEnter", function()
      btn._hovered = true
      paintButton(btn, true)
      if opt.tooltip and _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(btn, "ANCHOR_TOP")
        _G.GameTooltip:SetText(opt.label)
        if _G.GameTooltip.AddLine then
          _G.GameTooltip:AddLine(opt.tooltip, 1, 1, 1, true)
        end
        _G.GameTooltip:Show()
      end
    end)

    btn:SetScript("OnLeave", function()
      btn._hovered = false
      paintButton(btn, false)
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)

    table.insert(buttons, btn)
  end

  updateSelection(selected)

  return {
    row = row,
    label = labelFs,
    buttons = buttons,
    setSelected = updateSelection,
    setColors = function(nextColors)
      if type(nextColors) == "table" then
        palette.bg = nextColors.bg or palette.bg
        palette.bgHover = nextColors.bgHover or palette.bgHover
        palette.bgActive = nextColors.bgActive or palette.bgActive
        palette.text = nextColors.text or palette.text
        palette.textHover = nextColors.textHover or palette.textHover
        palette.textActive = nextColors.textActive or palette.textActive
      end
      repaintButtons()
    end,
    applyTheme = function(activeTheme, nextColors)
      UIHelpers.setTextColor(labelFs, activeTheme.COLORS.text_primary)
      if nextColors then
        palette.bg = nextColors.bg or palette.bg
        palette.bgHover = nextColors.bgHover or palette.bgHover
        palette.bgActive = nextColors.bgActive or palette.bgActive
        palette.text = nextColors.text or palette.text
        palette.textHover = nextColors.textHover or palette.textHover
        palette.textActive = nextColors.textActive or palette.textActive
      end
      repaintButtons()
    end,
  }
end

local function pctFormat(v)
  return tostring(math.floor(v * 100 + 0.5)) .. "%"
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
  opacityInactiveRow.row:SetPoint("TOPLEFT", fontSelector.row, "BOTTOMLEFT", 0, -ROW_SPACING)

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
  end)

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    UIHelpers.setTextColor(title, activeTheme.COLORS.text_primary)
    UIHelpers.setTextColor(hint, activeTheme.COLORS.text_secondary)

    local activeSelectorColors = selectorColorsFor(activeTheme)
    themePresetSelector.applyTheme(activeTheme, activeSelectorColors)
    fontSelector.applyTheme(activeTheme, activeSelectorColors)

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
    opacityInactiveSlider = opacityInactiveRow.slider,
    opacityActiveSlider = opacityActiveRow.slider,
    resetButton = resetButton,
    refreshTheme = refreshTheme,
  }
end

ns.AppearanceSettings = AppearanceSettings
return AppearanceSettings
