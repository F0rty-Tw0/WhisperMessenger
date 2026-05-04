local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")

local createOptionButton = UIHelpers.createOptionButton

local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

local GeneralSettings = {}

local PADDING = Theme.CONTENT_PADDING

local DEFAULTS = {
  maxMessagesPerConversation = 200,
  maxConversations = 100,
  messageMaxAge = 86400,
  clearOnLogout = false,
  hideMessagePreview = false,
  timeFormat = "12h",
  timeSource = "local",
  interfaceLanguage = "auto",
}

local function buildTimeFormatOptions(language)
  return {
    { key = "12h", label = Localization.Text("12-hour", language), tooltip = Localization.Text("Display times as 2:30 PM.", language) },
    { key = "24h", label = Localization.Text("24-hour", language), tooltip = Localization.Text("Display times as 14:30.", language) },
  }
end

local function buildTimeSourceOptions(language)
  return {
    { key = "local", label = Localization.Text("Local Time", language), tooltip = Localization.Text("Use your computer's clock.", language) },
    { key = "server", label = Localization.Text("Server Time", language), tooltip = Localization.Text("Use the game server's clock.", language) },
  }
end

function GeneralSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local interfaceLanguage = config.interfaceLanguage or DEFAULTS.interfaceLanguage
  local function text(key)
    return Localization.Text(key, interfaceLanguage)
  end

  local timeFormatOptions = buildTimeFormatOptions(interfaceLanguage)
  local timeSourceOptions = buildTimeSourceOptions(interfaceLanguage)
  local languageOptions = Localization.LanguageOptions(interfaceLanguage)

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local header = SettingsControls.CreateHeader(frame, {
    title = text("General Settings"),
    hint = text("Configure message storage, retention, and interface language."),
  })
  local hint = header.hint

  local toggleColors = SettingsControls.ToggleColors(Theme)
  local toggleLayout = { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 }
  local selectorColors = SettingsControls.SelectorColors(Theme)
  local panel = SettingsControls.NewPanelRegistry()

  local messagesRow = panel:bind(
    SettingsControls.CreateSliderRow(factory, frame, {
      label = text("Max Messages Per Contact"),
      min = 50,
      max = 500,
      step = 10,
      initial = config.maxMessagesPerConversation or 200,
      onChange = function(value)
        onChange("maxMessagesPerConversation", value)
      end,
    }),
    { type = "slider", key = "maxMessagesPerConversation", default = DEFAULTS.maxMessagesPerConversation }
  )
  messagesRow.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local conversationsRow = panel:bind(
    SettingsControls.CreateSliderRow(factory, frame, {
      label = text("Max Contacts"),
      min = 10,
      max = 100,
      step = 10,
      initial = config.maxConversations or 100,
      onChange = function(value)
        onChange("maxConversations", value)
      end,
    }),
    { type = "slider", key = "maxConversations", default = DEFAULTS.maxConversations }
  )
  conversationsRow.row:SetPoint("TOPLEFT", messagesRow.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local retentionHours = math.floor((config.messageMaxAge or 86400) / 3600 + 0.5)
  -- Retention slider stores hours in the UI but the config is seconds; reset
  -- has to convert the seconds-based default back to hours before SetValue.
  local retentionRow = panel:bind(
    SettingsControls.CreateSliderRow(factory, frame, {
      label = text("Message Retention (hours)"),
      min = 1,
      max = 168,
      step = 1,
      initial = retentionHours,
      onChange = function(value)
        onChange("messageMaxAge", value * 3600)
      end,
    }),
    {
      type = "slider",
      reset = function(control)
        control.slider:SetValue(math.floor(DEFAULTS.messageMaxAge / 3600 + 0.5))
      end,
    }
  )
  retentionRow.row:SetPoint("TOPLEFT", conversationsRow.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local privacyLabel = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  privacyLabel:SetPoint("TOPLEFT", retentionRow.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)
  privacyLabel:SetText(text("Privacy"))
  UIHelpers.setTextColor(privacyLabel, Theme.COLORS.text_secondary)

  local clearOnLogoutToggle = panel:bind(
    UIHelpers.createToggleRow(factory, frame, text("Clear on logout"), config.clearOnLogout == true, toggleColors, toggleLayout, function(value)
      onChange("clearOnLogout", value)
    end, {
      text("Clear on logout"),
      text("Deletes all saved conversations and contacts when you log out."),
    }),
    { type = "toggle", key = "clearOnLogout", default = DEFAULTS.clearOnLogout }
  )
  clearOnLogoutToggle.row:SetPoint("TOPLEFT", privacyLabel, "BOTTOMLEFT", 0, -12)

  local hidePreviewToggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      text("Hide message preview"),
      config.hideMessagePreview == true,
      toggleColors,
      toggleLayout,
      function(value)
        onChange("hideMessagePreview", value)
      end,
      {
        text("Hide message preview"),
        text("Hides the last message preview text in the contacts list for privacy."),
      }
    ),
    { type = "toggle", key = "hideMessagePreview", default = DEFAULTS.hideMessagePreview }
  )
  hidePreviewToggle.row:SetPoint("TOPLEFT", clearOnLogoutToggle.row, "BOTTOMLEFT", 0, -12)

  local timeLabel = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  timeLabel:SetPoint("TOPLEFT", hidePreviewToggle.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)
  timeLabel:SetText(text("Time Display"))
  UIHelpers.setTextColor(timeLabel, Theme.COLORS.text_secondary)

  local timeFormatSelector = panel:bind(
    ButtonSelector.Create(factory, frame, {
      labelText = text("Time Format"),
      optionsList = timeFormatOptions,
      fallbackKey = DEFAULTS.timeFormat,
      initial = config.timeFormat or DEFAULTS.timeFormat,
      colors = selectorColors,
      onChange = function(value)
        onChange("timeFormat", value)
      end,
      rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
      labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
    }),
    { type = "selector", key = "timeFormat", default = DEFAULTS.timeFormat }
  )
  timeFormatSelector.row:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -12)

  local timeSourceSelector = panel:bind(
    ButtonSelector.Create(factory, frame, {
      labelText = text("Time Source"),
      optionsList = timeSourceOptions,
      fallbackKey = DEFAULTS.timeSource,
      initial = config.timeSource or DEFAULTS.timeSource,
      colors = selectorColors,
      onChange = function(value)
        onChange("timeSource", value)
      end,
      rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
      labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
    }),
    { type = "selector", key = "timeSource", default = DEFAULTS.timeSource }
  )
  timeSourceSelector.row:SetPoint("TOPLEFT", timeFormatSelector.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local languageSelector = panel:bind(
    ButtonSelector.Create(factory, frame, {
      labelText = text("Interface Language"),
      optionsList = languageOptions,
      fallbackKey = DEFAULTS.interfaceLanguage,
      initial = interfaceLanguage,
      colors = selectorColors,
      onChange = function(value)
        onChange("interfaceLanguage", value)
      end,
      rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
      labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
      -- 12 options (Auto + 11 languages) wrap into a 3-column grid so each
      -- button stays wide enough to render its native autonym.
      maxPerRow = 3,
    }),
    { type = "selector", key = "interfaceLanguage", default = DEFAULTS.interfaceLanguage }
  )
  languageSelector.row:SetPoint("TOPLEFT", timeSourceSelector.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local resetButton = panel:bind(
    createOptionButton(
      factory,
      frame,
      text("Reset to Defaults"),
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH }
    ),
    { type = "optionButton" }
  )
  resetButton:SetPoint("TOPLEFT", languageSelector.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  resetButton:SetScript("OnClick", function()
    panel:reset(onChange)
  end)

  local function applyLanguage(nextLanguage)
    interfaceLanguage = nextLanguage or DEFAULTS.interfaceLanguage
    header.title:SetText(text("General Settings"))
    header.hint:SetText(text("Configure message storage, retention, and interface language."))
    messagesRow.label:SetText(text("Max Messages Per Contact"))
    conversationsRow.label:SetText(text("Max Contacts"))
    retentionRow.label:SetText(text("Message Retention (hours)"))
    privacyLabel:SetText(text("Privacy"))
    clearOnLogoutToggle.label:SetText(text("Clear on logout"))
    hidePreviewToggle.label:SetText(text("Hide message preview"))
    timeLabel:SetText(text("Time Display"))
    timeFormatSelector.label:SetText(text("Time Format"))
    timeFormatSelector.setOptionsList(buildTimeFormatOptions(interfaceLanguage))
    timeSourceSelector.label:SetText(text("Time Source"))
    timeSourceSelector.setOptionsList(buildTimeSourceOptions(interfaceLanguage))
    languageSelector.label:SetText(text("Interface Language"))
    languageSelector.setOptionsList(Localization.LanguageOptions(interfaceLanguage))
    languageSelector.setSelected(interfaceLanguage)
    resetButton.label:SetText(text("Reset to Defaults"))
  end

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)
  frame._wmBottomMarker = bottomSpacer

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
    UIHelpers.setTextColor(privacyLabel, activeTheme.COLORS.text_secondary)
    UIHelpers.setTextColor(timeLabel, activeTheme.COLORS.text_secondary)
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
    refreshLayout = refreshLayout,
    maxMessagesSlider = messagesRow.slider,
    maxConversationsSlider = conversationsRow.slider,
    retentionSlider = retentionRow.slider,
    maxMessagesMinLabel = messagesRow.minLabel,
    maxMessagesMaxLabel = messagesRow.maxLabel,
    maxConversationsMinLabel = conversationsRow.minLabel,
    maxConversationsMaxLabel = conversationsRow.maxLabel,
    retentionMinLabel = retentionRow.minLabel,
    retentionMaxLabel = retentionRow.maxLabel,
    clearOnLogoutToggle = clearOnLogoutToggle,
    hidePreviewToggle = hidePreviewToggle,
    timeFormatSelector = timeFormatSelector,
    timeSourceSelector = timeSourceSelector,
    languageSelector = languageSelector,
    resetButton = resetButton,
    refreshTheme = refreshTheme,
    setLanguage = applyLanguage,
  }
end

ns.GeneralSettings = GeneralSettings
return GeneralSettings
