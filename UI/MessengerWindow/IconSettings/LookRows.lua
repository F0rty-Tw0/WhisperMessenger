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

-- The widget shape selector, hung below controls.anchor; picks go to changed.
local function createShapeSelector(factory, frame, panel, config, controls, changed)
  local shapeSelector = panel:bind(
    ButtonSelector.Create(factory, frame, {
      labelText = text("Widget shape"),
      optionsList = Options.BuildWidgetShapeOptions(),
      fallbackKey = DEFAULTS.widgetShape,
      initial = config.widgetShape or DEFAULTS.widgetShape,
      colors = controls.selectorColors,
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
  shapeSelector.row:SetPoint("TOPLEFT", controls.anchor, "BOTTOMLEFT", 0, controls.rowSpacing)

  return shapeSelector
end

-- Returns toggleRow(label, tooltip, key, initial), which binds one on/off row
-- whose clicks go to changed(key, value).
local function toggleRowMaker(factory, frame, panel, controls, changed)
  return function(label, tooltip, key, initial)
    local function onClick(value)
      changed(key, value)
    end
    local toggle = UIHelpers.createToggleRow(
      factory,
      frame,
      text(label),
      initial,
      controls.toggleColors,
      controls.toggleLayout,
      onClick,
      { text(label), text(tooltip) }
    )

    return panel:bind(toggle, { type = "toggle", key = key, default = DEFAULTS[key] })
  end
end

-- The Button background, Show border and Color border with theme rows, in
-- that order below aboveRow.
local function createToggleRows(toggleRow, aboveRow, config, rowSpacing)
  local backgroundToggle = toggleRow(
    "Button background",
    "Shows the circle or square behind the widget icon. Turn it off to show only the two chat bubbles.",
    "iconBackground",
    config.iconBackground ~= false
  )
  backgroundToggle.row:SetPoint("TOPLEFT", aboveRow, "BOTTOMLEFT", 0, rowSpacing)

  local borderToggle = toggleRow(
    "Show border",
    "Draws a ring around the widget and the minimap button, or a frame around the square widget.",
    "iconBorder",
    config.iconBorder ~= false
  )
  borderToggle.row:SetPoint("TOPLEFT", backgroundToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local borderThemedToggle = toggleRow(
    "Color border with theme",
    "Tints the border to the theme's accent color. Turn it off for the gold border.",
    "iconBorderThemed",
    config.iconBorderThemed ~= false
  )
  borderThemedToggle.row:SetPoint("TOPLEFT", borderToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  return backgroundToggle, borderToggle, borderThemedToggle
end

-- controls: toggleColors, toggleLayout, selectorColors, rowSpacing, and
-- anchor (the row the shape selector hangs below).
function LookRows.Create(factory, frame, panel, config, onChange, controls)
  local borderOn = config.iconBorder ~= false
  local refreshAvailability

  -- Toggle clicks and Reset to Defaults both land here, so the themed toggle follows the border at once.
  local function changed(key, value)
    if key == "iconBorder" then
      borderOn = value
      refreshAvailability()
    end
    onChange(key, value)
  end

  local toggleRow = toggleRowMaker(factory, frame, panel, controls, changed)
  local shapeSelector = createShapeSelector(factory, frame, panel, config, controls, changed)
  local backgroundToggle, borderToggle, borderThemedToggle = createToggleRows(toggleRow, shapeSelector.row, config, controls.rowSpacing)

  -- Always shown, but only usable while the border is on; keeps its value meanwhile.
  local themedAvailability = UIHelpers.attachDisabledState(factory, borderThemedToggle.row)
  refreshAvailability = function()
    local disabledReason = text("Only with Show border on.")
    themedAvailability.set(borderOn, not borderOn and disabledReason or nil)
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
