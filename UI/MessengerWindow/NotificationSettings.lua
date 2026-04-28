local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")

local NotificationSettings = {}

local PADDING = Theme.CONTENT_PADDING

local DEFAULTS = {
  badgePulse = true,
  playSoundOnWhisper = false,
  showUnreadBadge = true,
  notificationSound = "whisper",
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

local SOUND_OPTIONS = {
  { key = "whisper", label = "Whisper" },
  { key = "ping", label = "Ping" },
  { key = "chime", label = "Chime" },
  { key = "bell", label = "Bell" },
  { key = "raid_warning", label = "RW" },
  { key = "ready", label = "Ready" },
  { key = "queue", label = "Queue" },
  { key = "alert", label = "Alert" },
  { key = "sigil", label = "Sigil" },
  { key = "map", label = "Map" },
  { key = "ding", label = "Ding" },
  { key = "glyph", label = "Glyph" },
  { key = "orb", label = "Orb" },
  { key = "spark", label = "Spark" },
  { key = "echo", label = "Echo" },
  { key = "pulse", label = "Pulse" },
}

local function createSoundSelector(factory, parent, initial, colors, onChange)
  return ButtonSelector.Create(factory, parent, {
    labelText = "Notification sound",
    optionsList = SOUND_OPTIONS,
    fallbackKey = DEFAULTS.notificationSound,
    initial = initial,
    colors = colors,
    onChange = function(value)
      if onChange then
        onChange(value)
      end
      local SoundPlayer = ns.SoundPlayer
      if SoundPlayer and SoundPlayer.Preview then
        SoundPlayer.Preview(value)
      end
    end,
    rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
    labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
    buttonWidth = 50,
    buttonHeight = 26,
    buttonSpacing = 4,
    maxPerRow = 6,
  })
end

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

  local title = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  title:SetText("Notifications")
  UIHelpers.setTextColor(title, Theme.COLORS.text_primary)

  local hint = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  hint:SetText("Configure alerts for incoming messages.")
  if hint.SetWordWrap then
    hint:SetWordWrap(true)
  end
  if hint.SetJustifyH then
    hint:SetJustifyH("LEFT")
  end
  if hint.SetWidth then
    hint:SetWidth(Theme.LAYOUT.SETTINGS_CONTROL_WIDTH)
  end
  UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)

  local toggleColors = SettingsControls.ToggleColors(Theme)
  local toggleLayout = { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 }

  local rowSpacing = -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING

  local playSoundToggle = UIHelpers.createToggleRow(
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
  )
  playSoundToggle.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -24)

  local selectorColors = SettingsControls.SelectorColors(Theme)
  local soundSelector = createSoundSelector(factory, frame, config.notificationSound or DEFAULTS.notificationSound, selectorColors, function(value)
    onChange("notificationSound", value)
  end)
  soundSelector.row:SetPoint("TOPLEFT", playSoundToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local iconSizeRow = SettingsControls.CreateSliderRow(factory, frame, {
    label = "Icon Size",
    min = 24,
    max = 64,
    step = 2,
    initial = config.iconSize or DEFAULTS.iconSize,
    formatFn = pxFormat,
    onChange = function(value)
      onChange("iconSize", value)
    end,
  })
  iconSizeRow.row:SetPoint("TOPLEFT", soundSelector.row, "BOTTOMLEFT", 0, rowSpacing)

  local iconDesaturatedToggle = UIHelpers.createToggleRow(
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
  )
  iconDesaturatedToggle.row:SetPoint("TOPLEFT", iconSizeRow.row, "BOTTOMLEFT", 0, rowSpacing)

  local showBadgeToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Show unread badge",
    config.showUnreadBadge ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("showUnreadBadge", value)
    end,
    {
      "Show unread badge",
      "Displays an unread message count on the toggle icon.",
    }
  )
  showBadgeToggle.row:SetPoint("TOPLEFT", iconDesaturatedToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local badgePulseToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Badge pulse animation",
    config.badgePulse ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("badgePulse", value)
    end,
    {
      "Badge pulse animation",
      "Plays a pulsing glow on the unread badge when new whispers arrive.",
    }
  )
  badgePulseToggle.row:SetPoint("TOPLEFT", showBadgeToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local widgetMessagePreviewToggle = UIHelpers.createToggleRow(
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
  )
  widgetMessagePreviewToggle.row:SetPoint("TOPLEFT", badgePulseToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local initialAutoDismiss = tonumber(config.widgetPreviewAutoDismissSeconds)
  if initialAutoDismiss == nil then
    initialAutoDismiss = DEFAULTS.widgetPreviewAutoDismissSeconds
  end
  local autoDismissRow = SettingsControls.CreateSliderRow(factory, frame, {
    label = "Auto-dismiss widget preview",
    min = 0,
    max = 120,
    step = 5,
    initial = initialAutoDismiss,
    formatFn = secondsFormat,
    onChange = function(value)
      onChange("widgetPreviewAutoDismissSeconds", value)
    end,
  })
  autoDismissRow.row:SetPoint("TOPLEFT", widgetMessagePreviewToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local positionSelector = ButtonSelector.Create(factory, frame, {
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
  })
  positionSelector.row:SetPoint("TOPLEFT", autoDismissRow.row, "BOTTOMLEFT", 0, rowSpacing)

  local normalColors = SettingsControls.OptionButtonColors(Theme)
  local resetButton = UIHelpers.createOptionButton(
    factory,
    frame,
    "Reset to Defaults",
    normalColors,
    { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH }
  )
  resetButton:SetPoint("TOPLEFT", positionSelector.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    playSoundToggle.setValue(DEFAULTS.playSoundOnWhisper)
    onChange("playSoundOnWhisper", DEFAULTS.playSoundOnWhisper)
    soundSelector.setSelected(DEFAULTS.notificationSound)
    onChange("notificationSound", DEFAULTS.notificationSound)
    iconSizeRow.slider:SetValue(DEFAULTS.iconSize)
    onChange("iconSize", DEFAULTS.iconSize)
    iconDesaturatedToggle.setValue(DEFAULTS.iconDesaturated)
    onChange("iconDesaturated", DEFAULTS.iconDesaturated)
    showBadgeToggle.setValue(DEFAULTS.showUnreadBadge)
    onChange("showUnreadBadge", DEFAULTS.showUnreadBadge)
    badgePulseToggle.setValue(DEFAULTS.badgePulse)
    onChange("badgePulse", DEFAULTS.badgePulse)
    widgetMessagePreviewToggle.setValue(DEFAULTS.showWidgetMessagePreview)
    onChange("showWidgetMessagePreview", DEFAULTS.showWidgetMessagePreview)
    autoDismissRow.slider:SetValue(DEFAULTS.widgetPreviewAutoDismissSeconds)
    onChange("widgetPreviewAutoDismissSeconds", DEFAULTS.widgetPreviewAutoDismissSeconds)
    positionSelector.setSelected(DEFAULTS.widgetPreviewPosition)
    onChange("widgetPreviewPosition", DEFAULTS.widgetPreviewPosition)
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)
  frame._wmBottomMarker = bottomSpacer

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    UIHelpers.setTextColor(title, activeTheme.COLORS.text_primary)
    UIHelpers.setTextColor(hint, activeTheme.COLORS.text_secondary)

    local activeToggleColors = SettingsControls.ToggleColors(activeTheme)
    badgePulseToggle.applyThemeColors(activeToggleColors)
    playSoundToggle.applyThemeColors(activeToggleColors)
    showBadgeToggle.applyThemeColors(activeToggleColors)
    iconDesaturatedToggle.applyThemeColors(activeToggleColors)
    widgetMessagePreviewToggle.applyThemeColors(activeToggleColors)

    iconSizeRow.applyTheme(activeTheme)
    autoDismissRow.applyTheme(activeTheme)
    soundSelector.applyTheme(activeTheme, SettingsControls.SelectorColors(activeTheme))
    positionSelector.applyTheme(activeTheme, SettingsControls.SelectorColors(activeTheme))

    if resetButton.applyThemeColors then
      resetButton.applyThemeColors(SettingsControls.OptionButtonColors(activeTheme))
    end
  end

  refreshTheme(Theme)

  local function refreshLayout(width)
    if type(width) ~= "number" or width <= 0 then
      return
    end
    local maxWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
    local effective = math.min(maxWidth, math.max(160, math.floor(width)))
    if hint.SetWidth then
      hint:SetWidth(effective)
    end
    playSoundToggle.setWidth(effective)
    soundSelector.setWidth(effective)
    iconSizeRow.setWidth(effective)
    iconDesaturatedToggle.setWidth(effective)
    showBadgeToggle.setWidth(effective)
    badgePulseToggle.setWidth(effective)
    widgetMessagePreviewToggle.setWidth(effective)
    autoDismissRow.setWidth(effective)
    positionSelector.setWidth(effective)
    if resetButton.setWidth then
      resetButton.setWidth(effective)
    end
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
