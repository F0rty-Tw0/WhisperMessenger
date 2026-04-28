local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture
local PanelRegistry = ns.SettingsControlsPanelRegistry or require("WhisperMessenger.UI.Shared.SettingsControls.PanelRegistry")

local SettingsControls = {}

-- Theme color builders --------------------------------------------------------

function SettingsControls.SelectorColors(activeTheme)
  return {
    bg = activeTheme.COLORS.option_button_bg,
    bgHover = activeTheme.COLORS.option_button_hover,
    bgActive = activeTheme.COLORS.option_button_active or activeTheme.COLORS.bg_contact_selected,
    text = activeTheme.COLORS.option_button_text,
    textHover = activeTheme.COLORS.option_button_text_hover,
    textActive = activeTheme.COLORS.option_button_text_active or activeTheme.COLORS.text_primary,
  }
end

function SettingsControls.ToggleColors(activeTheme)
  return {
    text = activeTheme.COLORS.text_primary,
    on = activeTheme.COLORS.option_toggle_on or activeTheme.COLORS.online,
    off = activeTheme.COLORS.option_toggle_off or activeTheme.COLORS.offline,
    border = activeTheme.COLORS.option_toggle_border or activeTheme.COLORS.divider,
  }
end

function SettingsControls.OptionButtonColors(activeTheme)
  return {
    bg = activeTheme.COLORS.option_button_bg,
    bgHover = activeTheme.COLORS.option_button_hover,
    text = activeTheme.COLORS.option_button_text,
    textHover = activeTheme.COLORS.option_button_text_hover,
  }
end

-- Settings panel header (title + hint) ----------------------------------------

function SettingsControls.CreateHeader(frame, opts)
  opts = opts or {}
  local PADDING = Theme.CONTENT_PADDING
  local CONTROL_WIDTH = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH

  local title = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  title:SetText(opts.title or "")
  UIHelpers.setTextColor(title, Theme.COLORS.text_primary)

  local hint = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  hint:SetText(opts.hint or "")
  if hint.SetWordWrap then
    hint:SetWordWrap(true)
  end
  if hint.SetJustifyH then
    hint:SetJustifyH("LEFT")
  end
  if hint.SetWidth then
    hint:SetWidth(CONTROL_WIDTH)
  end
  UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)

  return {
    title = title,
    hint = hint,
    refreshTheme = function(activeTheme)
      activeTheme = activeTheme or Theme
      UIHelpers.setTextColor(title, activeTheme.COLORS.text_primary)
      UIHelpers.setTextColor(hint, activeTheme.COLORS.text_secondary)
    end,
    refreshLayout = function(width)
      if hint.SetWidth and type(width) == "number" and width > 0 then
        hint:SetWidth(width)
      end
    end,
  }
end

-- Slider row ------------------------------------------------------------------

function SettingsControls.CreateSliderRow(factory, parent, spec)
  local label = spec.label
  local min = spec.min
  local max = spec.max
  local step = spec.step
  local initial = spec.initial
  local formatFn = spec.formatFn
  local onChange = spec.onChange

  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, Theme.LAYOUT.SETTINGS_SLIDER_HEIGHT + 20)

  local labelFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText(label)
  UIHelpers.setTextColor(labelFs, Theme.COLORS.text_primary)

  local valueFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  valueFs:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
  UIHelpers.setTextColor(valueFs, Theme.COLORS.text_secondary)

  local slider = factory.CreateFrame("Slider", nil, row)
  slider:SetSize(Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, Theme.LAYOUT.SETTINGS_SLIDER_HEIGHT)
  slider:SetPoint("TOPLEFT", labelFs, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_LABEL_SPACING)
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

  local sliderHeight = Theme.LAYOUT.SETTINGS_SLIDER_HEIGHT

  return {
    row = row,
    label = labelFs,
    value = valueFs,
    slider = slider,
    sliderBg = bg,
    minLabel = minLabel,
    maxLabel = maxLabel,
    setWidth = function(nextWidth)
      if type(nextWidth) ~= "number" or nextWidth <= 0 then
        return
      end
      row:SetSize(nextWidth, sliderHeight + 20)
      slider:SetSize(nextWidth, sliderHeight)
    end,
    applyTheme = function(activeTheme)
      UIHelpers.setTextColor(labelFs, activeTheme.COLORS.text_primary)
      UIHelpers.setTextColor(valueFs, activeTheme.COLORS.text_secondary)
      applyColorTexture(bg, activeTheme.COLORS.option_button_bg)
      UIHelpers.setTextColor(minLabel, activeTheme.COLORS.text_secondary)
      UIHelpers.setTextColor(maxLabel, activeTheme.COLORS.text_secondary)
    end,
  }
end

-- Toggle list (vertical anchor chain) -----------------------------------------
--
-- specs : array of { label, initial, onChange, tooltipLines }
-- anchorFrame : the frame the FIRST toggle anchors below
-- Returns an array of toggle objects (same order as specs).
function SettingsControls.BuildToggleList(factory, parent, anchorFrame, specs)
  local toggleColors = SettingsControls.ToggleColors(Theme)
  local toggleLayout = { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 }

  local toggles = {}
  local previous = nil
  for i, spec in ipairs(specs) do
    local toggle = UIHelpers.createToggleRow(factory, parent, spec.label, spec.initial, toggleColors, toggleLayout, spec.onChange, spec.tooltipLines)
    if previous == nil then
      local offsetY = spec.anchorOffsetY or -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
      toggle.row:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, offsetY)
    else
      toggle.row:SetPoint("TOPLEFT", previous.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING)
    end
    toggles[i] = toggle
    previous = toggle
  end
  return toggles
end

-- Build a label->option list by projecting a list of keys through a label map.
-- labelMap : { [key] = { label, tooltip } }
-- keys     : ordered list of keys (array)
-- fallback : default { label, tooltip } used when a key is missing from labelMap
function SettingsControls.ProjectLabeledOptions(keys, labelMap, fallback)
  local options = {}
  for _, key in ipairs(keys) do
    local meta = labelMap[key] or fallback(key)
    options[#options + 1] = { key = key, label = meta.label, tooltip = meta.tooltip }
  end
  return options
end

function SettingsControls.NewPanelRegistry()
  return PanelRegistry.New({
    toggleColors = SettingsControls.ToggleColors,
    selectorColors = SettingsControls.SelectorColors,
    optionButtonColors = SettingsControls.OptionButtonColors,
  })
end

ns.SettingsControls = SettingsControls
return SettingsControls
