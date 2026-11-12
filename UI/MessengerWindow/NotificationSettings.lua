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
  flashTaskbarOnWhisper = true,
  playSoundOnRequest = false,
  requestSound = "ping",
  mentionSound = SoundSelector.DEFAULT_SOUND,
  playSoundOnSend = false,
  sentSound = "chime",
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

  local requestSoundToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      text("Play sound on message request"),
      config.playSoundOnRequest == true,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("playSoundOnRequest", value)
      end,
      {
        text("Play sound on message request"),
        text("Plays a sound when a whisper from a stranger lands in Requests. Pick the sound below."),
        text('Turn on "Put whispers from strangers in Requests" to use this.'),
      }
    ),
    { type = "toggle", key = "playSoundOnRequest", default = DEFAULTS.playSoundOnRequest }
  )
  requestSoundToggle.row:SetPoint("TOPLEFT", soundSelector.row, "BOTTOMLEFT", 0, rowSpacing)

  local requestSoundSelector = panel:bind(
    SoundSelector.Create(factory, frame, {
      labelText = text("Request sound"),
      initial = config.requestSound or DEFAULTS.requestSound,
      colors = selectorColors,
      onChange = function(value)
        onChange("requestSound", value)
      end,
    }),
    { type = "selector", key = "requestSound", default = DEFAULTS.requestSound }
  )
  requestSoundSelector.row:SetPoint("TOPLEFT", requestSoundToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  -- Unset, a mention plays the whisper pick, so the picker shows that.
  local mentionSoundSelector = panel:bind(
    SoundSelector.Create(factory, frame, {
      labelText = text("Mention sound"),
      initial = config.mentionSound or config.notificationSound or DEFAULTS.notificationSound,
      colors = selectorColors,
      onChange = function(value)
        onChange("mentionSound", value)
      end,
    }),
    { type = "selector", key = "mentionSound", default = DEFAULTS.mentionSound }
  )
  mentionSoundSelector.row:SetPoint("TOPLEFT", requestSoundSelector.row, "BOTTOMLEFT", 0, rowSpacing)

  local sentSoundToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      text("Play sound when you send a whisper"),
      config.playSoundOnSend == true,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("playSoundOnSend", value)
      end,
      {
        text("Play sound when you send a whisper"),
        text("Plays a sound each time a whisper you write here is sent. Pick the sound below."),
      }
    ),
    { type = "toggle", key = "playSoundOnSend", default = DEFAULTS.playSoundOnSend }
  )
  sentSoundToggle.row:SetPoint("TOPLEFT", mentionSoundSelector.row, "BOTTOMLEFT", 0, rowSpacing)

  local sentSoundSelector = panel:bind(
    SoundSelector.Create(factory, frame, {
      labelText = text("Sent whisper sound"),
      initial = config.sentSound or DEFAULTS.sentSound,
      colors = selectorColors,
      onChange = function(value)
        onChange("sentSound", value)
      end,
    }),
    { type = "selector", key = "sentSound", default = DEFAULTS.sentSound }
  )
  sentSoundSelector.row:SetPoint("TOPLEFT", sentSoundToggle.row, "BOTTOMLEFT", 0, rowSpacing)

  local flashToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      text("Flash taskbar on new whisper"),
      config.flashTaskbarOnWhisper ~= false,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("flashTaskbarOnWhisper", value)
      end,
      {
        text("Flash taskbar on new whisper"),
        text("Flashes the game's taskbar icon when a whisper or a mention arrives while you are tabbed out."),
      }
    ),
    { type = "toggle", key = "flashTaskbarOnWhisper", default = DEFAULTS.flashTaskbarOnWhisper }
  )
  flashToggle.row:SetPoint("TOPLEFT", sentSoundSelector.row, "BOTTOMLEFT", 0, rowSpacing)

  local resetButton = panel:bind(
    UIHelpers.createOptionButton(
      factory,
      frame,
      text("Reset to Defaults"),
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, ghost = true }
    ),
    { type = "optionButton" }
  )
  resetButton:SetPoint("TOPLEFT", flashToggle.row, "BOTTOMLEFT", 0, -24)
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
    requestSoundToggle.label:SetText(text("Play sound on message request"))
    requestSoundSelector.label:SetText(text("Request sound"))
    requestSoundSelector.setOptionsList(SoundSelector.Options())
    mentionSoundSelector.label:SetText(text("Mention sound"))
    mentionSoundSelector.setOptionsList(SoundSelector.Options())
    sentSoundToggle.label:SetText(text("Play sound when you send a whisper"))
    sentSoundSelector.label:SetText(text("Sent whisper sound"))
    sentSoundSelector.setOptionsList(SoundSelector.Options())
    flashToggle.label:SetText(text("Flash taskbar on new whisper"))
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
    refreshTheme = refreshTheme,
    refreshLayout = refreshLayout,
    setLanguage = setLanguage,
  }
end

ns.NotificationSettings = NotificationSettings
return NotificationSettings
