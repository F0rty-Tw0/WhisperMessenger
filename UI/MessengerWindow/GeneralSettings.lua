local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")

local createOptionButton = UIHelpers.createOptionButton

local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local RetentionRow = ns.MessengerWindowGeneralSettingsRetentionRow or require("WhisperMessenger.UI.MessengerWindow.GeneralSettings.RetentionRow")
local TimeSection = ns.MessengerWindowGeneralSettingsTimeSection or require("WhisperMessenger.UI.MessengerWindow.GeneralSettings.TimeSection")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

local GeneralSettings = {}

local PADDING = Theme.CONTENT_PADDING

local DEFAULTS = {
  maxMessagesPerConversation = 200,
  maxConversations = 100,
  clearOnLogout = false,
  hideMessagePreview = false,
  hideBattleTagNumbers = true,
  showPlayerLevels = false,
  showRelationshipMarks = true,
  whoLookups = true,
  interfaceLanguage = "auto",
}

function GeneralSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local interfaceLanguage = config.interfaceLanguage or DEFAULTS.interfaceLanguage
  local function text(key)
    return Localization.Text(key, interfaceLanguage)
  end

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

  local function toggleRow(key, label, tooltip, initial, anchor, gap)
    local toggle = panel:bind(
      UIHelpers.createToggleRow(factory, frame, text(label), initial, toggleColors, toggleLayout, function(value)
        onChange(key, value)
      end, { text(label), text(tooltip) }),
      { type = "toggle", key = key, default = DEFAULTS[key] }
    )
    toggle.row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, gap or -12)
    return toggle
  end

  local playerLevelsToggle = toggleRow(
    "showPlayerLevels",
    "Show player levels",
    "Shows a player's level, colored by how it compares to yours, in the chat header and after names in group and channel chats.",
    config.showPlayerLevels == true,
    hint,
    -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING
  )
  local relationshipMarksToggle = toggleRow(
    "showRelationshipMarks",
    "Show relationship marks",
    "Show a small icon next to names for guildmates, friends and community members.",
    config.showRelationshipMarks ~= false,
    playerLevelsToggle.row
  )
  local whoLookupsToggle = toggleRow(
    "whoLookups",
    "Look up players with /who",
    "Fills in a player's zone, guild, class and online status with a quiet /who when you open a chat.",
    config.whoLookups ~= false,
    relationshipMarksToggle.row
  )

  local messagesRow = panel:bind(
    SettingsControls.CreateSliderRow(factory, frame, {
      label = text("Max Messages Per Chat"),
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
  messagesRow.row:SetPoint("TOPLEFT", whoLookupsToggle.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

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

  local retentionRow = panel:bind(
    RetentionRow.Create(factory, frame, {
      language = interfaceLanguage,
      initial = config.messageMaxAge,
      colors = selectorColors,
      onChange = function(seconds)
        onChange("messageMaxAge", seconds)
      end,
    }),
    {
      type = "selector",
      reset = function(control, resetOnChange)
        control.resetToDefault(resetOnChange)
      end,
    }
  )
  retentionRow.row:SetPoint("TOPLEFT", conversationsRow.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local privacySection = SettingsControls.CreateSectionLabel(frame, text("Privacy"))
  privacySection.region:SetPoint("TOPLEFT", retentionRow.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local clearOnLogoutToggle = toggleRow(
    "clearOnLogout",
    "Clear on logout",
    "Deletes all saved conversations and contacts when you log out.",
    config.clearOnLogout == true,
    privacySection.region
  )
  local hidePreviewToggle = toggleRow(
    "hideMessagePreview",
    "Hide message preview",
    "Hides the last message preview text in the contacts list for privacy.",
    config.hideMessagePreview == true,
    clearOnLogoutToggle.row
  )
  local hideBattleTagToggle = toggleRow(
    "hideBattleTagNumbers",
    "Hide BattleTag numbers",
    "Shows Battle.net friends without the #1234 part of their BattleTag. Two friends with the same name keep their numbers.",
    config.hideBattleTagNumbers ~= false,
    hidePreviewToggle.row
  )

  local timeSection = TimeSection.Create(factory, frame, {
    panel = panel,
    language = interfaceLanguage,
    config = config,
    colors = selectorColors,
    anchor = hideBattleTagToggle.row,
    onChange = onChange,
  })

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
  languageSelector.row:SetPoint("TOPLEFT", timeSection.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  local resetButton = panel:bind(
    createOptionButton(
      factory,
      frame,
      text("Reset to Defaults"),
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, ghost = true }
    ),
    { type = "optionButton" }
  )
  resetButton:SetPoint("TOPLEFT", languageSelector.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)

  resetButton:SetScript("OnClick", function()
    retentionRow.confirmReset(function()
      panel:reset(onChange)
    end)
  end)

  local function applyLanguage(nextLanguage)
    interfaceLanguage = nextLanguage or DEFAULTS.interfaceLanguage
    header.title:SetText(text("General Settings"))
    header.hint:SetText(text("Configure message storage, retention, and interface language."))
    playerLevelsToggle.label:SetText(text("Show player levels"))
    relationshipMarksToggle.label:SetText(text("Show relationship marks"))
    whoLookupsToggle.label:SetText(text("Look up players with /who"))
    messagesRow.label:SetText(text("Max Messages Per Chat"))
    conversationsRow.label:SetText(text("Max Contacts"))
    retentionRow.setLanguage(interfaceLanguage)
    privacySection.label:SetText(text("Privacy"))
    clearOnLogoutToggle.label:SetText(text("Clear on logout"))
    hidePreviewToggle.label:SetText(text("Hide message preview"))
    hideBattleTagToggle.label:SetText(text("Hide BattleTag numbers"))
    timeSection.setLanguage(interfaceLanguage)
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
    privacySection.refreshTheme(activeTheme)
    timeSection.refreshTheme(activeTheme)
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
    privacySection.refreshLayout(effective)
    timeSection.refreshLayout(effective)
    panel:refreshLayout(effective)
  end

  return {
    frame = frame,
    refreshLayout = refreshLayout,
    refreshTheme = refreshTheme,
    setLanguage = applyLanguage,
  }
end

ns.GeneralSettings = GeneralSettings
return GeneralSettings
