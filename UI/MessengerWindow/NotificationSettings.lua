local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local ButtonSelector = ns.MessengerWindowButtonSelector
  or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")

local NotificationSettings = {}

local PADDING = Theme.CONTENT_PADDING
local TOGGLE_WIDTH = 280
local ROW_SPACING = 16
local LABEL_SPACING = 6

local DEFAULTS = {
  badgePulse = true,
  playSoundOnWhisper = false,
  showUnreadBadge = true,
  notificationSound = "whisper",
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
    rowWidth = TOGGLE_WIDTH,
    labelSpacing = LABEL_SPACING,
    buttonWidth = 50,
    buttonHeight = 26,
    buttonSpacing = 4,
  })
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
  local toggleLayout = { width = TOGGLE_WIDTH, height = 24 }

  local badgePulseToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Badge pulse animation",
    config.badgePulse ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("badgePulse", value)
    end
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
    end
  )
  playSoundToggle.row:SetPoint("TOPLEFT", badgePulseToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

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
  soundSelector.row:SetPoint("TOPLEFT", playSoundToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local showBadgeToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Show unread badge",
    config.showUnreadBadge ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("showUnreadBadge", value)
    end
  )
  showBadgeToggle.row:SetPoint("TOPLEFT", soundSelector.row, "BOTTOMLEFT", 0, -ROW_SPACING)

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
    { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = TOGGLE_WIDTH }
  )
  resetButton:SetPoint("TOPLEFT", showBadgeToggle.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    badgePulseToggle.setValue(DEFAULTS.badgePulse)
    onChange("badgePulse", DEFAULTS.badgePulse)
    playSoundToggle.setValue(DEFAULTS.playSoundOnWhisper)
    onChange("playSoundOnWhisper", DEFAULTS.playSoundOnWhisper)
    soundSelector.setSelected(DEFAULTS.notificationSound)
    onChange("notificationSound", DEFAULTS.notificationSound)
    showBadgeToggle.setValue(DEFAULTS.showUnreadBadge)
    onChange("showUnreadBadge", DEFAULTS.showUnreadBadge)
  end)

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    UIHelpers.setTextColor(title, activeTheme.COLORS.text_primary)
    UIHelpers.setTextColor(hint, activeTheme.COLORS.text_secondary)

    local activeToggleColors = toggleColorsFor(activeTheme)
    badgePulseToggle.applyThemeColors(activeToggleColors)
    playSoundToggle.applyThemeColors(activeToggleColors)
    showBadgeToggle.applyThemeColors(activeToggleColors)

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
    resetButton = resetButton,
    refreshTheme = refreshTheme,
  }
end

ns.NotificationSettings = NotificationSettings
return NotificationSettings
