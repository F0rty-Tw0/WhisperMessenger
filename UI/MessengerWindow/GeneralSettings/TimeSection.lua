local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- The General page's "Time Display" section: its label and the Time Format
-- and Time Source selectors, bound to the page's panel registry for Reset.
local TimeSection = {}

TimeSection.DEFAULTS = {
  timeFormat = "12h",
  timeSource = "local",
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

-- options: panel, language, config, colors, anchor, onChange(key, value).
-- Returns the last row (to anchor below), setLanguage, refreshTheme and
-- refreshLayout.
function TimeSection.Create(factory, frame, options)
  local panel = options.panel
  local config = options.config
  local language = options.language
  local spacing = Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING

  local section = SettingsControls.CreateSectionLabel(frame, Localization.Text("Time Display", language))
  section.region:SetPoint("TOPLEFT", options.anchor, "BOTTOMLEFT", 0, -spacing)

  local function selector(key, label, optionsList)
    return panel:bind(
      ButtonSelector.Create(factory, frame, {
        labelText = Localization.Text(label, language),
        optionsList = optionsList,
        fallbackKey = TimeSection.DEFAULTS[key],
        initial = config[key] or TimeSection.DEFAULTS[key],
        colors = options.colors,
        onChange = function(value)
          options.onChange(key, value)
        end,
        rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
        labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
      }),
      { type = "selector", key = key, default = TimeSection.DEFAULTS[key] }
    )
  end

  local formatSelector = selector("timeFormat", "Time Format", buildTimeFormatOptions(language))
  formatSelector.row:SetPoint("TOPLEFT", section.region, "BOTTOMLEFT", 0, -12)
  local sourceSelector = selector("timeSource", "Time Source", buildTimeSourceOptions(language))
  sourceSelector.row:SetPoint("TOPLEFT", formatSelector.row, "BOTTOMLEFT", 0, -spacing)

  local function setLanguage(nextLanguage)
    section.label:SetText(Localization.Text("Time Display", nextLanguage))
    formatSelector.label:SetText(Localization.Text("Time Format", nextLanguage))
    formatSelector.setOptionsList(buildTimeFormatOptions(nextLanguage))
    sourceSelector.label:SetText(Localization.Text("Time Source", nextLanguage))
    sourceSelector.setOptionsList(buildTimeSourceOptions(nextLanguage))
  end

  return {
    row = sourceSelector.row,
    setLanguage = setLanguage,
    refreshTheme = section.refreshTheme,
    refreshLayout = section.refreshLayout,
  }
end

ns.MessengerWindowGeneralSettingsTimeSection = TimeSection
return TimeSection
