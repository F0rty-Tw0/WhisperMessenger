local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local Options = ns.IconSettingsOptions or require("WhisperMessenger.UI.MessengerWindow.IconSettings.Options")

-- The Icons panel rows for how unread whispers show on the widget: badge,
-- badge pulse, the message preview's auto-dismiss delay and its position.
-- The preview and reply toggles themselves live on the Whispers page.
local UnreadRows = {}

local DEFAULTS = Options.DEFAULTS

local function text(key)
  return Localization.Text(key)
end

-- controls: toggleColors, toggleLayout, selectorColors, rowSpacing, and
-- anchor (the row the first unread row hangs below).
function UnreadRows.Create(factory, frame, panel, config, onChange, controls)
  local toggleColors = controls.toggleColors
  local toggleLayout = controls.toggleLayout
  local selectorColors = controls.selectorColors
  local rowSpacing = controls.rowSpacing

  local showBadgeToggle = panel:bind(
    UIHelpers.createToggleRow(factory, frame, text("Show unread badge"), config.showUnreadBadge ~= false, toggleColors, toggleLayout, function(value)
      onChange("showUnreadBadge", value)
    end, {
      text("Show unread badge"),
      text("Displays an unread message count on the toggle icon."),
    }),
    { type = "toggle", key = "showUnreadBadge", default = DEFAULTS.showUnreadBadge }
  )
  showBadgeToggle.row:SetPoint("TOPLEFT", controls.anchor, "BOTTOMLEFT", 0, rowSpacing)

  local badgePulseToggle = panel:bind(
    UIHelpers.createToggleRow(factory, frame, text("Badge pulse animation"), config.badgePulse ~= false, toggleColors, toggleLayout, function(value)
      onChange("badgePulse", value)
    end, {
      text("Badge pulse animation"),
      text("Plays a pulsing glow on the unread badge when new whispers arrive."),
    }),
    { type = "toggle", key = "badgePulse", default = DEFAULTS.badgePulse }
  )
  badgePulseToggle.row:SetPoint("TOPLEFT", showBadgeToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local initialAutoDismiss = tonumber(config.widgetPreviewAutoDismissSeconds)
  if initialAutoDismiss == nil then
    initialAutoDismiss = DEFAULTS.widgetPreviewAutoDismissSeconds
  end
  local autoDismissRow = panel:bind(
    SettingsControls.CreateSliderRow(factory, frame, {
      label = text("Auto-dismiss widget preview"),
      min = 0,
      max = 120,
      step = 5,
      initial = initialAutoDismiss,
      formatFn = Options.SecondsFormat,
      onChange = function(value)
        onChange("widgetPreviewAutoDismissSeconds", value)
      end,
    }),
    { type = "slider", key = "widgetPreviewAutoDismissSeconds", default = DEFAULTS.widgetPreviewAutoDismissSeconds }
  )
  autoDismissRow.row:SetPoint("TOPLEFT", badgePulseToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local positionSelector = panel:bind(
    ButtonSelector.Create(factory, frame, {
      labelText = text("Widget preview position"),
      optionsList = Options.BuildPositionOptions(),
      fallbackKey = DEFAULTS.widgetPreviewPosition,
      initial = config.widgetPreviewPosition or DEFAULTS.widgetPreviewPosition,
      colors = selectorColors,
      onChange = function(value)
        onChange("widgetPreviewPosition", value)
      end,
      rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
      labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
      buttonWidth = Options.SELECTOR_BUTTON_WIDTH,
      buttonHeight = Options.SELECTOR_BUTTON_HEIGHT,
      buttonSpacing = Options.SELECTOR_BUTTON_SPACING,
      maxPerRow = 4,
    }),
    { type = "selector", key = "widgetPreviewPosition", default = DEFAULTS.widgetPreviewPosition }
  )
  positionSelector.row:SetPoint("TOPLEFT", autoDismissRow.row, "BOTTOMLEFT", 0, rowSpacing)

  local function setLanguage()
    showBadgeToggle.label:SetText(text("Show unread badge"))
    badgePulseToggle.label:SetText(text("Badge pulse animation"))
    autoDismissRow.label:SetText(text("Auto-dismiss widget preview"))
    positionSelector.label:SetText(text("Widget preview position"))
    positionSelector.setOptionsList(Options.BuildPositionOptions())
  end

  return {
    showBadgeToggle = showBadgeToggle,
    badgePulseToggle = badgePulseToggle,
    autoDismissRow = autoDismissRow,
    positionSelector = positionSelector,
    setLanguage = setLanguage,
  }
end

ns.IconSettingsUnreadRows = UnreadRows
return UnreadRows
