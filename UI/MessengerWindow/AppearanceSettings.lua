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

local DEFAULTS = {
  windowOpacityInactive = 0.72,
  windowOpacityActive = 1.0,
}

local function createSliderRow(factory, parent, label, min, max, step, initial, formatFn, onChange)
  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(SLIDER_WIDTH, SLIDER_HEIGHT + 20)

  local labelFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText(label)
  UIHelpers.setTextColor(labelFs, Theme.COLORS.text_primary)

  local valueFs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

  local minLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
  minLabel:SetText(formatFn and formatFn(min) or tostring(min))
  UIHelpers.setTextColor(minLabel, Theme.COLORS.text_secondary)

  local maxLabel = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
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

local function pctFormat(v)
  return tostring(math.floor(v * 100 + 0.5)) .. "%"
end

function AppearanceSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function() end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  title:SetText("Appearance")
  UIHelpers.setTextColor(title, Theme.COLORS.text_primary)

  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  hint:SetText("Customize window opacity.")
  UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)

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
  opacityInactiveRow.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -ROW_SPACING)

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
  end)

  return {
    frame = frame,
    opacityInactiveSlider = opacityInactiveRow.slider,
    opacityActiveSlider = opacityActiveRow.slider,
    resetButton = resetButton,
  }
end

ns.AppearanceSettings = AppearanceSettings
return AppearanceSettings
