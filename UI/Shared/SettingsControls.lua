local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local PanelRegistry = ns.SettingsControlsPanelRegistry or require("WhisperMessenger.UI.Shared.SettingsControls.PanelRegistry")
local Header = ns.SettingsControlsHeader or require("WhisperMessenger.UI.Shared.SettingsControls.Header")
local SectionLabel = ns.SettingsControlsSectionLabel or require("WhisperMessenger.UI.Shared.SettingsControls.SectionLabel")
local SliderSkin = ns.SettingsControlsSliderSkin or require("WhisperMessenger.UI.Shared.SettingsControls.SliderSkin")
local NativeControls = ns.UIHelpersNativeControls or require("WhisperMessenger.UI.Helpers.NativeControls")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")

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
    knob = activeTheme.COLORS.control_knob,
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

-- Settings panel header (title + hint): see SettingsControls/Header.lua.
SettingsControls.CreateHeader = Header.Create

-- Sub-section label inside a page: see SettingsControls/SectionLabel.lua.
SettingsControls.CreateSectionLabel = SectionLabel.Create

-- Slider row ------------------------------------------------------------------

function SettingsControls.CreateSliderRow(factory, parent, spec)
  local label = spec.label
  local min = spec.min
  local max = spec.max
  local step = spec.step
  local initial = spec.initial
  local formatFn = spec.formatFn
  local onChange = spec.onChange
  local tooltip = spec.tooltip
  local commitOnRelease = spec.commitOnRelease == true

  local row = factory.CreateFrame("Frame", nil, parent)
  row:SetSize(Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, Theme.LAYOUT.SETTINGS_SLIDER_HEIGHT + 20)

  local labelFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  labelFs:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  labelFs:SetText(label)

  local valueFs = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  valueFs:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)

  -- Native WoW HUD: Blizzard slider; the template draws track and thumb.
  local nativeSlider = Hud.IsOn() and NativeControls.CreateSlider(factory, row) or nil
  local slider = nativeSlider or factory.CreateFrame("Slider", nil, row)
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

  -- Track; SliderSkin.Attach anchors it as a thin centred line.
  local bg = not nativeSlider and slider:CreateTexture(nil, "BACKGROUND") or nil

  local minLabel = slider:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
  minLabel:SetText(formatFn and formatFn(min) or tostring(min))

  local maxLabel = slider:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
  maxLabel:SetText(formatFn and formatFn(max) or tostring(max))

  local skin = nativeSlider and SliderSkin.AttachNative(slider, NativeControls.SliderThumbSize(slider)) or SliderSkin.Attach(slider, bg)

  local function paintLabels(activeTheme)
    local valueColor, rangeColor = SliderSkin.LabelColors(activeTheme)
    UIHelpers.setTextColor(labelFs, activeTheme.COLORS.text_primary)
    UIHelpers.setTextColor(valueFs, valueColor)
    UIHelpers.setTextColor(minLabel, rangeColor)
    UIHelpers.setTextColor(maxLabel, rangeColor)
  end

  slider:SetValue(initial)
  valueFs:SetText(formatFn and formatFn(initial) or tostring(initial))
  SliderSkin.Apply(skin, Theme)
  paintLabels(Theme)

  local dragActive = false
  local pendingValue
  local valueChangeGeneration = 0
  local layoutResizeActive = false

  slider:SetScript("OnValueChanged", function(_self, value, userInput)
    SliderSkin.UpdateFill(skin)
    if layoutResizeActive then
      return
    end
    valueChangeGeneration = valueChangeGeneration + 1
    local stepped = math.floor(value / step + 0.5) * step
    valueFs:SetText(formatFn and formatFn(stepped) or tostring(stepped))
    if commitOnRelease and dragActive and userInput == true then
      pendingValue = stepped
      return
    end
    if commitOnRelease and dragActive then
      pendingValue = nil
    end
    if onChange then
      onChange(stepped)
    end
  end)

  if commitOnRelease then
    -- Release-committed values are disruptive to apply (window scale), so a
    -- stray track click must not jump the value either.
    SliderSkin.BlockTrackClicks(skin, factory)

    local originalOnMouseDown = slider:GetScript("OnMouseDown")
    local originalOnMouseUp = slider:GetScript("OnMouseUp")

    slider:SetScript("OnMouseDown", function(self, button, ...)
      if originalOnMouseDown then
        originalOnMouseDown(self, button, ...)
      end
      if button == "LeftButton" then
        dragActive = true
        pendingValue = nil
      end
    end)

    slider:SetScript("OnMouseUp", function(self, button, ...)
      local committedValue
      local releaseGeneration = valueChangeGeneration
      if button == "LeftButton" and dragActive then
        committedValue = pendingValue
        dragActive = false
        pendingValue = nil
      end
      if originalOnMouseUp then
        originalOnMouseUp(self, button, ...)
      end
      if committedValue ~= nil and releaseGeneration == valueChangeGeneration and onChange then
        onChange(committedValue)
      end
    end)
  end

  if tooltip and row.SetScript then
    local lines = type(tooltip) == "table" and tooltip or { tooltip }
    row:SetScript("OnEnter", function()
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(row, "ANCHOR_TOP")
        _G.GameTooltip:SetText(lines[1])
        for i = 2, #lines do
          if _G.GameTooltip.AddLine then
            pcall(_G.GameTooltip.AddLine, _G.GameTooltip, lines[i], 1, 1, 1)
          end
        end
        _G.GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function()
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)
  end

  local sliderHeight = Theme.LAYOUT.SETTINGS_SLIDER_HEIGHT

  return {
    row = row,
    label = labelFs,
    value = valueFs,
    slider = slider,
    fill = skin.fill,
    thumb = skin.thumb,
    minLabel = minLabel,
    maxLabel = maxLabel,
    setWidth = function(nextWidth)
      if type(nextWidth) ~= "number" or nextWidth <= 0 then
        return
      end
      row:SetSize(nextWidth, sliderHeight + 20)
      layoutResizeActive = true
      slider:SetSize(nextWidth, sliderHeight)
      layoutResizeActive = false
      SliderSkin.UpdateFill(skin)
    end,
    applyTheme = function(activeTheme)
      SliderSkin.Apply(skin, activeTheme)
      paintLabels(activeTheme)
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

-- Binds each toggle BuildToggleList made from `specs` to Reset to Defaults by
-- its setting key; spec.reset overrides it (e.g. for a CVar-backed toggle).
function SettingsControls.BindToggleSpecs(panel, toggles, specs, defaults)
  for i, spec in ipairs(specs) do
    panel:bind(toggles[i], { type = "toggle", key = spec.key, default = defaults[spec.key], reset = spec.reset })
  end
end

-- Relabels those toggles from each spec's English labelKey.
function SettingsControls.RelabelToggles(toggles, specs, translate)
  for i, spec in ipairs(specs) do
    toggles[i].label:SetText(translate(spec.labelKey))
  end
end

-- Build a label->option list by projecting a list of keys through a label map.
-- labelMap : { [key] = { label, tooltip } }
-- keys     : ordered list of keys (array)
-- fallback : default { label, tooltip } used when a key is missing from labelMap
function SettingsControls.ProjectLabeledOptions(keys, labelMap, fallback, localize)
  local options = {}
  local translate = localize or function(value)
    return value
  end
  for _, key in ipairs(keys) do
    local meta = labelMap[key] or fallback(key)
    options[#options + 1] = { key = key, label = translate(meta.label), tooltip = translate(meta.tooltip) }
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
