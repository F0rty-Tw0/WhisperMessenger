local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture
local ButtonSelector = ns.MessengerWindowButtonSelector
  or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")

local NotificationSettings = {}

local PADDING = Theme.CONTENT_PADDING

local DEFAULTS = {
  badgePulse = true,
  playSoundOnWhisper = false,
  showUnreadBadge = true,
  notificationSound = "whisper",
  iconSize = 42,
  iconDesaturated = true,
}

local SOUND_OPTIONS = {
  { key = "whisper", label = "Whisper" },
  { key = "ping", label = "Ping" },
  { key = "chime", label = "Chime" },
  { key = "bell", label = "Bell" },
  { key = "raid_warning", label = "RW" },
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
  })
end

local function createSliderRow(factory, parent, label, min, max, step, initial, formatFn, onChange)
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

  return {
    row = row,
    label = labelFs,
    value = valueFs,
    slider = slider,
    sliderBg = bg,
    minLabel = minLabel,
    maxLabel = maxLabel,
    applyTheme = function(activeTheme)
      UIHelpers.setTextColor(labelFs, activeTheme.COLORS.text_primary)
      UIHelpers.setTextColor(valueFs, activeTheme.COLORS.text_secondary)
      applyColorTexture(bg, activeTheme.COLORS.option_button_bg)
      UIHelpers.setTextColor(minLabel, activeTheme.COLORS.text_secondary)
      UIHelpers.setTextColor(maxLabel, activeTheme.COLORS.text_secondary)
    end,
  }
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

  local function toggleColorsFor(activeTheme)
    return {
      text = activeTheme.COLORS.text_primary,
      on = activeTheme.COLORS.option_toggle_on or activeTheme.COLORS.online,
      off = activeTheme.COLORS.option_toggle_off or activeTheme.COLORS.offline,
      border = activeTheme.COLORS.option_toggle_border or activeTheme.COLORS.divider,
    }
  end
  local toggleColors = toggleColorsFor(Theme)
  local toggleLayout = { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 }

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
  badgePulseToggle.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -24)

  local playSoundToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Notification sound",
    config.playSoundOnWhisper == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("playSoundOnWhisper", value)
    end,
    {
      "Notification sound",
      "Plays a sound alert when you receive a new whisper.",
    }
  )
  playSoundToggle.row:SetPoint(
    "TOPLEFT",
    badgePulseToggle.row,
    "BOTTOMLEFT",
    0,
    -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
  )

  local function selectorColorsFor(activeTheme)
    return {
      bg = activeTheme.COLORS.option_button_bg,
      bgHover = activeTheme.COLORS.option_button_hover,
      bgActive = activeTheme.COLORS.option_button_active or activeTheme.COLORS.bg_contact_selected,
      text = activeTheme.COLORS.option_button_text,
      textHover = activeTheme.COLORS.option_button_text_hover,
      textActive = activeTheme.COLORS.option_button_text_active or activeTheme.COLORS.text_primary,
    }
  end
  local selectorColors = selectorColorsFor(Theme)
  local soundSelector = createSoundSelector(
    factory,
    frame,
    config.notificationSound or DEFAULTS.notificationSound,
    selectorColors,
    function(value)
      onChange("notificationSound", value)
    end
  )
  soundSelector.row:SetPoint("TOPLEFT", playSoundToggle.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING)

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
  showBadgeToggle.row:SetPoint("TOPLEFT", soundSelector.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING)

  local function pxFormat(v)
    return tostring(math.floor(v + 0.5)) .. "px"
  end

  local iconSizeRow = createSliderRow(
    factory,
    frame,
    "Icon Size",
    24,
    64,
    2,
    config.iconSize or DEFAULTS.iconSize,
    pxFormat,
    function(value)
      onChange("iconSize", value)
    end
  )
  iconSizeRow.row:SetPoint("TOPLEFT", showBadgeToggle.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING)

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
  iconDesaturatedToggle.row:SetPoint(
    "TOPLEFT",
    iconSizeRow.row,
    "BOTTOMLEFT",
    0,
    -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
  )

  -- Reset button
  local function optionButtonColorsFor(activeTheme)
    return {
      bg = activeTheme.COLORS.option_button_bg,
      bgHover = activeTheme.COLORS.option_button_hover,
      text = activeTheme.COLORS.option_button_text,
      textHover = activeTheme.COLORS.option_button_text_hover,
    }
  end
  local normalColors = optionButtonColorsFor(Theme)
  local resetButton = UIHelpers.createOptionButton(
    factory,
    frame,
    "Reset to Defaults",
    normalColors,
    { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH }
  )
  resetButton:SetPoint("TOPLEFT", iconDesaturatedToggle.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    badgePulseToggle.setValue(DEFAULTS.badgePulse)
    onChange("badgePulse", DEFAULTS.badgePulse)
    playSoundToggle.setValue(DEFAULTS.playSoundOnWhisper)
    onChange("playSoundOnWhisper", DEFAULTS.playSoundOnWhisper)
    soundSelector.setSelected(DEFAULTS.notificationSound)
    onChange("notificationSound", DEFAULTS.notificationSound)
    showBadgeToggle.setValue(DEFAULTS.showUnreadBadge)
    onChange("showUnreadBadge", DEFAULTS.showUnreadBadge)
    iconSizeRow.slider:SetValue(DEFAULTS.iconSize)
    onChange("iconSize", DEFAULTS.iconSize)
    iconDesaturatedToggle.setValue(DEFAULTS.iconDesaturated)
    onChange("iconDesaturated", DEFAULTS.iconDesaturated)
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    UIHelpers.setTextColor(title, activeTheme.COLORS.text_primary)
    UIHelpers.setTextColor(hint, activeTheme.COLORS.text_secondary)

    local activeToggleColors = toggleColorsFor(activeTheme)
    badgePulseToggle.applyThemeColors(activeToggleColors)
    playSoundToggle.applyThemeColors(activeToggleColors)
    showBadgeToggle.applyThemeColors(activeToggleColors)
    iconDesaturatedToggle.applyThemeColors(activeToggleColors)

    iconSizeRow.applyTheme(activeTheme)
    soundSelector.applyTheme(activeTheme, selectorColorsFor(activeTheme))

    if resetButton.applyThemeColors then
      resetButton.applyThemeColors(optionButtonColorsFor(activeTheme))
    end
  end

  refreshTheme(Theme)

  return {
    frame = frame,
    badgePulseToggle = badgePulseToggle,
    playSoundToggle = playSoundToggle,
    soundSelector = soundSelector,
    showBadgeToggle = showBadgeToggle,
    iconSizeSlider = iconSizeRow.slider,
    iconDesaturatedToggle = iconDesaturatedToggle,
    resetButton = resetButton,
    refreshTheme = refreshTheme,
  }
end

ns.NotificationSettings = NotificationSettings
return NotificationSettings
