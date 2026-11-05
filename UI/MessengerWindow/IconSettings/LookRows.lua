local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Options = ns.IconSettingsOptions or require("WhisperMessenger.UI.MessengerWindow.IconSettings.Options")

-- The Icons panel rows for how the widget looks: its shape and the square
-- button background.
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

  local shape = config.widgetShape
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

  -- Only the square widget shape has a background to hide.
  local backgroundToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      text("Square button background"),
      config.iconBackground ~= false,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("iconBackground", value)
      end,
      {
        text("Square button background"),
        text("Shows a square behind the widget icon when the widget shape is square. Turn it off to show only the two chat bubbles."),
      }
    ),
    { type = "toggle", key = "iconBackground", default = DEFAULTS.iconBackground }
  )
  backgroundToggle.row:SetPoint("TOPLEFT", shapeSelector.row, "BOTTOMLEFT", 0, rowSpacing)
  -- Always shown, but only usable with the square shape; keeps its value meanwhile.
  local backgroundAvailability = UIHelpers.attachDisabledState(factory, backgroundToggle.row)
  local function refreshAvailability()
    local usable = shape == "square"
    local reason = not usable and text("Only with the square widget shape.") or nil
    backgroundAvailability.set(usable, reason)
  end
  -- Selector clicks and Reset to Defaults both land here, so the toggle follows the shape at once.
  changed = function(key, value)
    if key == "widgetShape" then
      shape = value
      refreshAvailability()
    end
    onChange(key, value)
  end

  refreshAvailability()

  local function setLanguage()
    shapeSelector.label:SetText(text("Widget shape"))
    shapeSelector.setOptionsList(Options.BuildWidgetShapeOptions())
    backgroundToggle.label:SetText(text("Square button background"))
    refreshAvailability()
  end

  return {
    shapeSelector = shapeSelector,
    backgroundToggle = backgroundToggle,
    lastRow = backgroundToggle.row,
    changed = changed,
    refreshAvailability = refreshAvailability,
    setLanguage = setLanguage,
  }
end

ns.IconSettingsLookRows = LookRows
return LookRows
