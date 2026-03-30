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
  { key = "default", label = "Default", tooltip = "Blizzard's built-in font (Friz Quadrata)." },
  { key = "system", label = "System", tooltip = "Clean sans-serif font (Arial Narrow)." },
  { key = "custom", label = "Custom", tooltip = "Inherits the font set by other addons like ElvUI." },
}

local DEFAULTS = {
  windowOpacityInactive = 0.72,
  windowOpacityActive = 1.0,
  fontFamily = "default",
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

  return { row = row, slider = slider, minLabel = minLabel, maxLabel = maxLabel }
end

local function createFontSelector(factory, parent, initial, colors, onChange)
  local BUTTON_WIDTH = 86
  local BUTTON_HEIGHT = 26
  local BUTTON_SPACING = 8

  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(SLIDER_WIDTH, BUTTON_HEIGHT + 20)

  local labelFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText("Font Family")
  UIHelpers.setTextColor(labelFs, Theme.COLORS.text_primary)

  local buttons = {}
  local selected = initial or "default"

  local function updateSelection(nextSelected)
    selected = nextSelected
    for _, entry in ipairs(buttons) do
      if entry._key == selected then
        entry._selected = true
        applyColorTexture(entry.bg, colors.bgActive or { 0.30, 0.82, 0.40, 1.0 })
        UIHelpers.setTextColor(entry.label, colors.textActive or Theme.COLORS.text_primary)
      else
        entry._selected = false
        applyColorTexture(entry.bg, colors.bg or Theme.COLORS.option_button_bg)
        UIHelpers.setTextColor(entry.label, colors.text or Theme.COLORS.option_button_text)
      end
    end
  end

  for i, opt in ipairs(FONT_OPTIONS) do
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
    btn.bg = bg
    btn.label = btnLabel

    btn:SetScript("OnClick", function()
      updateSelection(opt.key)
      if onChange then
        onChange(opt.key)
      end
    end)

    btn:SetScript("OnEnter", function()
      if btn._key ~= selected then
        applyColorTexture(bg, colors.bgHover or Theme.COLORS.option_button_hover)
        UIHelpers.setTextColor(btnLabel, colors.textHover or Theme.COLORS.option_button_text_hover)
      end
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
      if btn._key ~= selected then
        applyColorTexture(bg, colors.bg or Theme.COLORS.option_button_bg)
        UIHelpers.setTextColor(btnLabel, colors.text or Theme.COLORS.option_button_text)
      end
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)

    table.insert(buttons, btn)
  end

  updateSelection(selected)

  return {
    row = row,
    buttons = buttons,
    setSelected = updateSelection,
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
  hint:SetText("Customize fonts and window opacity.")
  UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)

  -- Font family selector
  local selectorColors = {
    bg = Theme.COLORS.option_button_bg,
    bgHover = Theme.COLORS.option_button_hover,
    bgActive = Theme.COLORS.accent_primary or { 0.30, 0.82, 0.40, 1.0 },
    text = Theme.COLORS.option_button_text,
    textHover = Theme.COLORS.option_button_text_hover,
    textActive = Theme.COLORS.text_primary,
  }
  local fontSelector = createFontSelector(
    factory,
    frame,
    config.fontFamily or DEFAULTS.fontFamily,
    selectorColors,
    function(value)
      onChange("fontFamily", value)
    end
  )
  fontSelector.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -ROW_SPACING)

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
  local normalColors = {
    bg = Theme.COLORS.option_button_bg,
    bgHover = Theme.COLORS.option_button_hover,
    text = Theme.COLORS.option_button_text,
    textHover = Theme.COLORS.option_button_text_hover,
  }
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
    fontSelector.setSelected(DEFAULTS.fontFamily)
    onChange("fontFamily", DEFAULTS.fontFamily)
  end)

  return {
    frame = frame,
    fontSelector = fontSelector,
    opacityInactiveSlider = opacityInactiveRow.slider,
    opacityActiveSlider = opacityActiveRow.slider,
    resetButton = resetButton,
  }
end

ns.AppearanceSettings = AppearanceSettings
return AppearanceSettings
