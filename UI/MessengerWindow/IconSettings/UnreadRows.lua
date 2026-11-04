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
-- badge pulse, message preview, the reply row under it, its auto-dismiss
-- delay and its position.
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

  -- Set once the reply toggle exists; the preview toggle calls it on change.
  local refreshReplyAvailability
  local widgetMessagePreviewToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      text("Show widget message preview"),
      config.showWidgetMessagePreview ~= false,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("showWidgetMessagePreview", value)
        refreshReplyAvailability(value)
      end,
      {
        text("Show widget message preview"),
        text("Shows sender name and the latest incoming whisper preview on the draggable widget."),
      }
    ),
    { type = "toggle", key = "showWidgetMessagePreview", default = DEFAULTS.showWidgetMessagePreview }
  )
  widgetMessagePreviewToggle.row:SetPoint("TOPLEFT", badgePulseToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local widgetPreviewReplyToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      text("Reply from widget preview"),
      config.widgetPreviewReply == true,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("widgetPreviewReply", value)
      end,
      {
        text("Reply from widget preview"),
        text("Adds a small reply box under the widget message preview. Press Enter to send."),
      }
    ),
    {
      type = "toggle",
      key = "widgetPreviewReply",
      default = DEFAULTS.widgetPreviewReply,
      -- The preview toggle's reset never fires its row callback, so the
      -- reply toggle's availability follows the preview default here.
      reset = function(control, onReset)
        control.setValue(DEFAULTS.widgetPreviewReply)
        if onReset then
          onReset("widgetPreviewReply", DEFAULTS.widgetPreviewReply)
        end
        refreshReplyAvailability(DEFAULTS.showWidgetMessagePreview ~= false)
      end,
    }
  )
  widgetPreviewReplyToggle.row:SetPoint("TOPLEFT", widgetMessagePreviewToggle.row, "BOTTOMLEFT", 0, rowSpacing)
  -- Moot while the preview is off; keeps its value meanwhile.
  local replyAvailability = UIHelpers.attachDisabledState(factory, widgetPreviewReplyToggle.row)
  refreshReplyAvailability = function(previewOn)
    replyAvailability.set(previewOn, not previewOn and text('Turn on "Show widget message preview" to use this.') or nil)
  end
  refreshReplyAvailability(config.showWidgetMessagePreview ~= false)

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
  autoDismissRow.row:SetPoint("TOPLEFT", widgetPreviewReplyToggle.row, "BOTTOMLEFT", 0, rowSpacing)

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
      buttonWidth = 60,
      buttonHeight = 26,
      buttonSpacing = 4,
      maxPerRow = 4,
    }),
    { type = "selector", key = "widgetPreviewPosition", default = DEFAULTS.widgetPreviewPosition }
  )
  positionSelector.row:SetPoint("TOPLEFT", autoDismissRow.row, "BOTTOMLEFT", 0, rowSpacing)

  local function setLanguage()
    showBadgeToggle.label:SetText(text("Show unread badge"))
    badgePulseToggle.label:SetText(text("Badge pulse animation"))
    widgetMessagePreviewToggle.label:SetText(text("Show widget message preview"))
    widgetPreviewReplyToggle.label:SetText(text("Reply from widget preview"))
    autoDismissRow.label:SetText(text("Auto-dismiss widget preview"))
    positionSelector.label:SetText(text("Widget preview position"))
    positionSelector.setOptionsList(Options.BuildPositionOptions())
  end

  return {
    showBadgeToggle = showBadgeToggle,
    badgePulseToggle = badgePulseToggle,
    widgetMessagePreviewToggle = widgetMessagePreviewToggle,
    widgetPreviewReplyToggle = widgetPreviewReplyToggle,
    widgetPreviewReplyAvailability = replyAvailability,
    autoDismissRow = autoDismissRow,
    positionSelector = positionSelector,
    setLanguage = setLanguage,
  }
end

ns.IconSettingsUnreadRows = UnreadRows
return UnreadRows
