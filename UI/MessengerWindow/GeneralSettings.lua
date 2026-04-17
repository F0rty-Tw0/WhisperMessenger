local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")

local createOptionButton = UIHelpers.createOptionButton

local ButtonSelector = ns.MessengerWindowButtonSelector
  or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")

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
}

local TIME_FORMAT_OPTIONS = {
  { key = "12h", label = "12-hour", tooltip = "Display times as 2:30 PM." },
  { key = "24h", label = "24-hour", tooltip = "Display times as 14:30." },
}

local TIME_SOURCE_OPTIONS = {
  { key = "local", label = "Local Time", tooltip = "Use your computer's clock." },
  { key = "server", label = "Server Time", tooltip = "Use the game server's clock." },
}

function GeneralSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local title = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  title:SetText("General Settings")
  UIHelpers.setTextColor(title, Theme.COLORS.text_primary)

  local hint = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  hint:SetText("Configure message storage and retention limits.")
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

  local messagesRow = SettingsControls.CreateSliderRow(factory, frame, {
    label = "Max Messages Per Contact",
    min = 50,
    max = 500,
    step = 10,
    initial = config.maxMessagesPerConversation or 200,
    onChange = function(value)
      onChange("maxMessagesPerConversation", value)
    end,
  })
  messagesRow.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local conversationsRow = SettingsControls.CreateSliderRow(factory, frame, {
    label = "Max Contacts",
    min = 10,
    max = 100,
    step = 10,
    initial = config.maxConversations or 100,
    onChange = function(value)
      onChange("maxConversations", value)
    end,
  })
  conversationsRow.row:SetPoint("TOPLEFT", messagesRow.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local retentionHours = math.floor((config.messageMaxAge or 86400) / 3600 + 0.5)
  local retentionRow = SettingsControls.CreateSliderRow(factory, frame, {
    label = "Message Retention (hours)",
    min = 1,
    max = 168,
    step = 1,
    initial = retentionHours,
    onChange = function(value)
      onChange("messageMaxAge", value * 3600)
    end,
  })
  retentionRow.row:SetPoint("TOPLEFT", conversationsRow.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local toggleColors = SettingsControls.ToggleColors(Theme)
  local toggleLayout = { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 }

  local privacyLabel = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  privacyLabel:SetPoint("TOPLEFT", retentionRow.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)
  privacyLabel:SetText("Privacy")
  UIHelpers.setTextColor(privacyLabel, Theme.COLORS.text_secondary)

  local clearOnLogoutToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Clear on logout",
    config.clearOnLogout == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("clearOnLogout", value)
    end,
    {
      "Clear on logout",
      "Deletes all saved conversations and contacts when you log out.",
    }
  )
  clearOnLogoutToggle.row:SetPoint("TOPLEFT", privacyLabel, "BOTTOMLEFT", 0, -12)

  local hidePreviewToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Hide message preview",
    config.hideMessagePreview == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("hideMessagePreview", value)
    end,
    {
      "Hide message preview",
      "Hides the last message preview text in the contacts list for privacy.",
    }
  )
  hidePreviewToggle.row:SetPoint("TOPLEFT", clearOnLogoutToggle.row, "BOTTOMLEFT", 0, -12)

  local selectorColors = SettingsControls.SelectorColors(Theme)

  local timeLabel = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  timeLabel:SetPoint("TOPLEFT", hidePreviewToggle.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)
  timeLabel:SetText("Time Display")
  UIHelpers.setTextColor(timeLabel, Theme.COLORS.text_secondary)

  local timeFormatSelector = ButtonSelector.Create(factory, frame, {
    labelText = "Time Format",
    optionsList = TIME_FORMAT_OPTIONS,
    fallbackKey = DEFAULTS.timeFormat,
    initial = config.timeFormat or DEFAULTS.timeFormat,
    colors = selectorColors,
    onChange = function(value)
      onChange("timeFormat", value)
    end,
    rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
    labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
  })
  timeFormatSelector.row:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 0, -12)

  local timeSourceSelector = ButtonSelector.Create(factory, frame, {
    labelText = "Time Source",
    optionsList = TIME_SOURCE_OPTIONS,
    fallbackKey = DEFAULTS.timeSource,
    initial = config.timeSource or DEFAULTS.timeSource,
    colors = selectorColors,
    onChange = function(value)
      onChange("timeSource", value)
    end,
    rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
    labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
  })
  timeSourceSelector.row:SetPoint(
    "TOPLEFT",
    timeFormatSelector.row,
    "BOTTOMLEFT",
    0,
    -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING
  )

  local normalColors = SettingsControls.OptionButtonColors(Theme)
  local resetButton = createOptionButton(
    factory,
    frame,
    "Reset to Defaults",
    normalColors,
    { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH }
  )
  resetButton:SetPoint("TOPLEFT", timeSourceSelector.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  resetButton:SetScript("OnClick", function()
    messagesRow.slider:SetValue(DEFAULTS.maxMessagesPerConversation)
    conversationsRow.slider:SetValue(DEFAULTS.maxConversations)
    retentionRow.slider:SetValue(math.floor(DEFAULTS.messageMaxAge / 3600 + 0.5))
    clearOnLogoutToggle.setValue(DEFAULTS.clearOnLogout)
    onChange("clearOnLogout", DEFAULTS.clearOnLogout)
    hidePreviewToggle.setValue(DEFAULTS.hideMessagePreview)
    onChange("hideMessagePreview", DEFAULTS.hideMessagePreview)
    timeFormatSelector.setSelected(DEFAULTS.timeFormat)
    onChange("timeFormat", DEFAULTS.timeFormat)
    timeSourceSelector.setSelected(DEFAULTS.timeSource)
    onChange("timeSource", DEFAULTS.timeSource)
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    UIHelpers.setTextColor(title, activeTheme.COLORS.text_primary)
    UIHelpers.setTextColor(hint, activeTheme.COLORS.text_secondary)
    UIHelpers.setTextColor(privacyLabel, activeTheme.COLORS.text_secondary)

    messagesRow.applyTheme(activeTheme)
    conversationsRow.applyTheme(activeTheme)
    retentionRow.applyTheme(activeTheme)

    local activeToggleColors = SettingsControls.ToggleColors(activeTheme)
    clearOnLogoutToggle.applyThemeColors(activeToggleColors)
    hidePreviewToggle.applyThemeColors(activeToggleColors)

    UIHelpers.setTextColor(timeLabel, activeTheme.COLORS.text_secondary)
    local activeSelectorColors = SettingsControls.SelectorColors(activeTheme)
    timeFormatSelector.applyTheme(activeTheme, activeSelectorColors)
    timeSourceSelector.applyTheme(activeTheme, activeSelectorColors)

    if resetButton.applyThemeColors then
      resetButton.applyThemeColors(SettingsControls.OptionButtonColors(activeTheme))
    end
  end

  refreshTheme(Theme)

  return {
    frame = frame,
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
    resetButton = resetButton,
    refreshTheme = refreshTheme,
  }
end

ns.GeneralSettings = GeneralSettings
return GeneralSettings
