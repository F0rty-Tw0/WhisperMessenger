local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local SoundSelector = ns.NotificationSettingsSoundSelector or require("WhisperMessenger.UI.MessengerWindow.NotificationSettings.SoundSelector")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

local NotificationSettings = {}

local PADDING = Theme.CONTENT_PADDING

local DEFAULTS = {
  playSoundOnWhisper = false,
  notificationSound = SoundSelector.DEFAULT_SOUND,
}

local function text(key)
  return Localization.Text(key)
end

function NotificationSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local header = SettingsControls.CreateHeader(frame, {
    title = text("Notifications"),
    hint = text("Configure alerts for incoming messages."),
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
      text("Play sound on new whisper"),
      config.playSoundOnWhisper == true,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("playSoundOnWhisper", value)
      end,
      {
        text("Play sound on new whisper"),
        text("Plays a sound alert when you receive a new whisper. Use the selector below to pick which sound."),
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

  local resetButton = panel:bind(
    UIHelpers.createOptionButton(
      factory,
      frame,
      text("Reset to Defaults"),
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH }
    ),
    { type = "optionButton" }
  )
  resetButton:SetPoint("TOPLEFT", soundSelector.row, "BOTTOMLEFT", 0, -24)
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

  local function setLanguage()
    header.title:SetText(text("Notifications"))
    header.hint:SetText(text("Configure alerts for incoming messages."))
    playSoundToggle.label:SetText(text("Play sound on new whisper"))
    soundSelector.label:SetText(text("Notification sound"))
    soundSelector.setOptionsList(SoundSelector.Options())
    resetButton.label:SetText(text("Reset to Defaults"))
  end

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
    playSoundToggle = playSoundToggle,
    soundSelector = soundSelector,
    resetButton = resetButton,
    refreshTheme = refreshTheme,
    refreshLayout = refreshLayout,
    setLanguage = setLanguage,
  }
end

ns.NotificationSettings = NotificationSettings
return NotificationSettings
