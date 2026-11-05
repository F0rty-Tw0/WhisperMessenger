local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Options = ns.IconSettingsOptions or require("WhisperMessenger.UI.MessengerWindow.IconSettings.Options")

-- The Icons panel rows for how the icons look: the widget shape, the button
-- background and the two border toggles.
local LookRows = {}

local DEFAULTS = Options.DEFAULTS

local function text(key)
  return Localization.Text(key)
end

-- controls: toggleColors, toggleLayout, selectorColors, rowSpacing, and
-- anchor (the row the shape selector hangs below).
function LookRows.Create(factory, frame, panel, config, onChange, controls)
  local toggleColors = controls.toggleColors
  local toggleLayout = controls.toggleLayout
  local selectorColors = controls.selectorColors
  local rowSpacing = controls.rowSpacing

  local borderOn = config.iconBorder ~= false
  local changed

  local shapeSelector = panel:bind(
    ButtonSelector.Create(factory, frame, {
      labelText = text("Widget shape"),
      optionsList = Options.BuildWidgetShapeOptions(),
      fallbackKey = DEFAULTS.widgetShape,
      initial = config.widgetShape or DEFAULTS.widgetShape,
      colors = selectorColors,
      onChange = function(value)
        changed("widgetShape", value)
      end,
      rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
      labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
      buttonWidth = Options.SELECTOR_BUTTON_WIDTH,
      buttonHeight = Options.SELECTOR_BUTTON_HEIGHT,
      buttonSpacing = Options.SELECTOR_BUTTON_SPACING,
      maxPerRow = 2,
    }),
    { type = "selector", key = "widgetShape", default = DEFAULTS.widgetShape }
  )
  shapeSelector.row:SetPoint("TOPLEFT", controls.anchor, "BOTTOMLEFT", 0, rowSpacing)

  local function toggleRow(label, tooltip, key, initial, onClick)
    return panel:bind(
      UIHelpers.createToggleRow(factory, frame, text(label), initial, toggleColors, toggleLayout, onClick, { text(label), text(tooltip) }),
      { type = "toggle", key = key, default = DEFAULTS[key] }
    )
  end

  local backgroundToggle = toggleRow(
    "Button background",
    "Shows the circle or square behind the widget icon. Turn it off to show only the two chat bubbles.",
    "iconBackground",
    config.iconBackground ~= false,
    function(value)
      onChange("iconBackground", value)
    end
  )
  backgroundToggle.row:SetPoint("TOPLEFT", shapeSelector.row, "BOTTOMLEFT", 0, rowSpacing)

  local borderToggle = toggleRow(
    "Show border",
    "Draws a ring around the widget and the minimap button, or a frame around the square widget.",
    "iconBorder",
    borderOn,
    function(value)
      changed("iconBorder", value)
    end
  )
  borderToggle.row:SetPoint("TOPLEFT", backgroundToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local borderThemedToggle = toggleRow(
    "Color border with theme",
    "Tints the border to the theme's accent color. Turn it off for the gold border.",
    "iconBorderThemed",
    config.iconBorderThemed ~= false,
    function(value)
      onChange("iconBorderThemed", value)
    end
  )
  borderThemedToggle.row:SetPoint("TOPLEFT", borderToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  -- Always shown, but only usable while the border is on; keeps its value meanwhile.
  local themedAvailability = UIHelpers.attachDisabledState(factory, borderThemedToggle.row)
  local function refreshAvailability()
    local reason = not borderOn and text("Only with Show border on.") or nil
    themedAvailability.set(borderOn, reason)
  end
  -- Toggle clicks and Reset to Defaults both land here, so the themed toggle follows the border at once.
  changed = function(key, value)
    if key == "iconBorder" then
      borderOn = value
      refreshAvailability()
    end
    onChange(key, value)
  end

  refreshAvailability()

  local function setLanguage()
    shapeSelector.label:SetText(text("Widget shape"))
    shapeSelector.setOptionsList(Options.BuildWidgetShapeOptions())
    backgroundToggle.label:SetText(text("Button background"))
    borderToggle.label:SetText(text("Show border"))
    borderThemedToggle.label:SetText(text("Color border with theme"))
    refreshAvailability()
  end

  return {
    shapeSelector = shapeSelector,
    backgroundToggle = backgroundToggle,
    borderToggle = borderToggle,
    borderThemedToggle = borderThemedToggle,
    lastRow = borderThemedToggle.row,
    changed = changed,
    refreshAvailability = refreshAvailability,
    setLanguage = setLanguage,
  }
end

ns.IconSettingsLookRows = LookRows
return LookRows
