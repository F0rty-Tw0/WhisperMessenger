local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Retention = ns.Retention or require("WhisperMessenger.Model.Retention")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local DropdownSelector = ns.MessengerWindowDropdownSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.DropdownSelector")

-- "Message Retention" dropdown of the General settings page. Each choice
-- stores its age in seconds under messageMaxAge. A saved value that matches
-- no choice (an hour count from the old slider) is listed as its own entry,
-- in age order, until the player picks something else; it is never rewritten.
local RetentionRow = {}

local HOUR = 3600
local DAY = 86400
local BUTTON_HEIGHT = 26

RetentionRow.DEFAULT_SECONDS = DAY

local PRESETS = {
  { seconds = HOUR, labelKey = "1 hour" },
  { seconds = 6 * HOUR, labelKey = "6 hours" },
  { seconds = 12 * HOUR, labelKey = "12 hours" },
  { seconds = DAY, labelKey = "1 day" },
  { seconds = 3 * DAY, labelKey = "3 days" },
  { seconds = 7 * DAY, labelKey = "7 days" },
  { seconds = 30 * DAY, labelKey = "30 days" },
  { seconds = 90 * DAY, labelKey = "90 days" },
  { seconds = Retention.FOREVER_SECONDS, labelKey = "Forever" },
}

-- Tall enough to list every choice plus one custom entry without scrolling.
local MENU_HEIGHT = (#PRESETS + 1) * BUTTON_HEIGHT

local function isPreset(seconds)
  for _, preset in ipairs(PRESETS) do
    if preset.seconds == seconds then
      return true
    end
  end
  return false
end

local function customOption(seconds, language)
  local hours = math.max(1, math.floor(seconds / HOUR + 0.5))
  return { key = seconds, label = string.format(Localization.Text("%d hours", language), hours) }
end

-- Choices for `language`, plus `current` as its own entry when it is a
-- saved age that matches no choice.
function RetentionRow.BuildOptions(language, current)
  local custom = nil
  if type(current) == "number" and not isPreset(current) then
    custom = customOption(current, language)
  end

  local options = {}
  for _, preset in ipairs(PRESETS) do
    if custom and custom.key < preset.seconds then
      options[#options + 1] = custom
      custom = nil
    end
    options[#options + 1] = { key = preset.seconds, label = Localization.Text(preset.labelKey, language) }
  end
  if custom then
    options[#options + 1] = custom
  end
  return options
end

-- options: { language, initial (seconds), onChange(seconds), rowWidth, labelSpacing, colors }
-- Returns the DropdownSelector handle plus setLanguage(language) and
-- resetToDefault(onChange) for the panel's Reset to Defaults button.
function RetentionRow.Create(factory, parent, options)
  local language = options.language
  local current = type(options.initial) == "number" and options.initial or RetentionRow.DEFAULT_SECONDS

  local control = DropdownSelector.Create(factory, parent, {
    labelText = Localization.Text("Message Retention", language),
    optionsList = RetentionRow.BuildOptions(language, current),
    -- Rebuilt on every open, so a stale custom entry leaves once the player
    -- has picked a listed choice.
    getOptions = function()
      return RetentionRow.BuildOptions(language, current)
    end,
    fallbackKey = RetentionRow.DEFAULT_SECONDS,
    initial = current,
    colors = options.colors,
    onChange = function(seconds)
      current = seconds
      options.onChange(seconds)
    end,
    rowWidth = options.rowWidth or Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
    labelSpacing = options.labelSpacing or Theme.LAYOUT.SETTINGS_LABEL_SPACING,
    buttonHeight = BUTTON_HEIGHT,
    menuHeight = MENU_HEIGHT,
  })

  function control.setLanguage(nextLanguage)
    language = nextLanguage
    control.label:SetText(Localization.Text("Message Retention", language))
    control.setOptionsList(RetentionRow.BuildOptions(language, current))
  end

  function control.resetToDefault(onChange)
    current = RetentionRow.DEFAULT_SECONDS
    control.setOptionsList(RetentionRow.BuildOptions(language, current))
    control.setSelected(current)
    if onChange then
      onChange("messageMaxAge", current)
    end
  end

  return control
end

ns.MessengerWindowGeneralSettingsRetentionRow = RetentionRow
return RetentionRow
