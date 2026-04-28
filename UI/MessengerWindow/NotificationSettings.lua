local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local SoundSelector = ns.NotificationSettingsSoundSelector or require("WhisperMessenger.UI.MessengerWindow.NotificationSettings.SoundSelector")

local NotificationSettings = {}

local PADDING = Theme.CONTENT_PADDING

local DEFAULTS = {
  badgePulse = true,
  playSoundOnWhisper = false,
  showUnreadBadge = true,
  notificationSound = SoundSelector.DEFAULT_SOUND,
  iconSize = 42,
  iconDesaturated = true,
  showWidgetMessagePreview = true,
  widgetPreviewAutoDismissSeconds = 30,
  widgetPreviewPosition = "right",
}

local POSITION_OPTIONS = {
  { key = "right", label = "Right" },
  { key = "left", label = "Left" },
  { key = "top", label = "Above" },
  { key = "bottom", label = "Below" },
}

local function pxFormat(v)
  return tostring(math.floor(v + 0.5)) .. "px"
end

local function secondsFormat(v)
  local n = math.floor(v + 0.5)
  if n <= 0 then
    return "Off"
  end
  return tostring(n) .. "s"
end

function NotificationSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local header = SettingsControls.CreateHeader(frame, {
    title = "Notifications",
    hint = "Configure alerts for incoming messages.",
  })
  local hint = header.hint

  local toggleColors = SettingsControls.ToggleColors(Theme)
  local toggleLayout = { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 }
  local selectorColors = SettingsControls.SelectorColors(Theme)
  local rowSpacing = -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
  local panel = SettingsControls.NewPanelRegistry()

  local playSoundToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      "Play sound on new whisper",
      config.playSoundOnWhisper == true,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("playSoundOnWhisper", value)
      end,
      {
        "Play sound on new whisper",
        "Plays a sound alert when you receive a new whisper. Use the selector below to pick which sound.",
      }
    ),
    { type = "toggle", key = "playSoundOnWhisper", default = DEFAULTS.playSoundOnWhisper }
  )
  playSoundToggle.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -24)

  local soundSelector = panel:bind(
    SoundSelector.Create(factory, frame, {
      initial = config.notificationSound or DEFAULTS.notificationSound,
      colors = selectorColors,
      onChange = function(value)
        onChange("notificationSound", value)
      end,
    }),
    { type = "selector", key = "notificationSound", default = DEFAULTS.notificationSound }
  )
  soundSelector.row:SetPoint("TOPLEFT", playSoundToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local iconSizeRow = panel:bind(
    SettingsControls.CreateSliderRow(factory, frame, {
      label = "Icon Size",
      min = 24,
      max = 64,
      step = 2,
      initial = config.iconSize or DEFAULTS.iconSize,
      formatFn = pxFormat,
      onChange = function(value)
        onChange("iconSize", value)
      end,
    }),
    { type = "slider", key = "iconSize", default = DEFAULTS.iconSize }
  )
  iconSizeRow.row:SetPoint("TOPLEFT", soundSelector.row, "BOTTOMLEFT", 0, rowSpacing)

  local iconDesaturatedToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      "Desaturate icon when idle",
      config.iconDesaturated ~= false,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("iconDesaturated", value)
      end,
      {
        "Desaturate icon when idle",
        "Greyscales the toggle icon when there are no unread messages.",
      }
    ),
    { type = "toggle", key = "iconDesaturated", default = DEFAULTS.iconDesaturated }
  )
  iconDesaturatedToggle.row:SetPoint("TOPLEFT", iconSizeRow.row, "BOTTOMLEFT", 0, rowSpacing)

  local showBadgeToggle = panel:bind(
    UIHelpers.createToggleRow(factory, frame, "Show unread badge", config.showUnreadBadge ~= false, toggleColors, toggleLayout, function(value)
      onChange("showUnreadBadge", value)
    end, {
      "Show unread badge",
      "Displays an unread message count on the toggle icon.",
    }),
    { type = "toggle", key = "showUnreadBadge", default = DEFAULTS.showUnreadBadge }
  )
  showBadgeToggle.row:SetPoint("TOPLEFT", iconDesaturatedToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local badgePulseToggle = panel:bind(
    UIHelpers.createToggleRow(factory, frame, "Badge pulse animation", config.badgePulse ~= false, toggleColors, toggleLayout, function(value)
      onChange("badgePulse", value)
    end, {
      "Badge pulse animation",
      "Plays a pulsing glow on the unread badge when new whispers arrive.",
    }),
    { type = "toggle", key = "badgePulse", default = DEFAULTS.badgePulse }
  )
  badgePulseToggle.row:SetPoint("TOPLEFT", showBadgeToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local widgetMessagePreviewToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      "Show widget message preview",
      config.showWidgetMessagePreview ~= false,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("showWidgetMessagePreview", value)
      end,
      {
        "Show widget message preview",
        "Shows sender name and the latest incoming whisper preview on the draggable widget.",
      }
    ),
    { type = "toggle", key = "showWidgetMessagePreview", default = DEFAULTS.showWidgetMessagePreview }
  )
  widgetMessagePreviewToggle.row:SetPoint("TOPLEFT", badgePulseToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local initialAutoDismiss = tonumber(config.widgetPreviewAutoDismissSeconds)
  if initialAutoDismiss == nil then
    initialAutoDismiss = DEFAULTS.widgetPreviewAutoDismissSeconds
  end
  local autoDismissRow = panel:bind(
    SettingsControls.CreateSliderRow(factory, frame, {
      label = "Auto-dismiss widget preview",
      min = 0,
      max = 120,
      step = 5,
      initial = initialAutoDismiss,
      formatFn = secondsFormat,
      onChange = function(value)
        onChange("widgetPreviewAutoDismissSeconds", value)
      end,
    }),
    { type = "slider", key = "widgetPreviewAutoDismissSeconds", default = DEFAULTS.widgetPreviewAutoDismissSeconds }
  )
  autoDismissRow.row:SetPoint("TOPLEFT", widgetMessagePreviewToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local positionSelector = panel:bind(
    ButtonSelector.Create(factory, frame, {
      labelText = "Widget preview position",
      optionsList = POSITION_OPTIONS,
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

  local resetButton = panel:bind(
    UIHelpers.createOptionButton(
      factory,
      frame,
      "Reset to Defaults",
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH }
    ),
    { type = "optionButton" }
  )
  resetButton:SetPoint("TOPLEFT", positionSelector.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    panel:reset(onChange)
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)
  frame._wmBottomMarker = bottomSpacer

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
    panel:refreshTheme(activeTheme)
  end

  refreshTheme(Theme)

  local function refreshLayout(width)
    if type(width) ~= "number" or width <= 0 then
      return
    end
    local maxWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
    local effective = math.min(maxWidth, math.max(160, math.floor(width)))
    header.refreshLayout(effective)
    panel:refreshLayout(effective)
  end

  return {
    frame = frame,
    badgePulseToggle = badgePulseToggle,
    playSoundToggle = playSoundToggle,
    soundSelector = soundSelector,
    showBadgeToggle = showBadgeToggle,
    iconSizeSlider = iconSizeRow.slider,
    iconDesaturatedToggle = iconDesaturatedToggle,
    widgetMessagePreviewToggle = widgetMessagePreviewToggle,
    autoDismissSlider = autoDismissRow.slider,
    positionSelector = positionSelector,
    resetButton = resetButton,
    refreshTheme = refreshTheme,
    refreshLayout = refreshLayout,
  }
end

ns.NotificationSettings = NotificationSettings
return NotificationSettings
