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
RetentionRow.CONFIRM_DIALOG = "WHISPER_MESSENGER_CONFIRM_SHORTER_RETENTION"

local CONFIRM_PROMPT = "Keep chat history for %s only? Older messages are deleted now."
local CONFIRM_RESET_PROMPT = "Reset this page to its defaults? Chat history is then kept for %s only, and older messages are deleted now."

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

local function labelFor(seconds, language, current)
  for _, option in ipairs(RetentionRow.BuildOptions(language, current)) do
    if option.key == seconds then
      return option.label
    end
  end
  return customOption(seconds, language).label
end

-- A prompt left open from an earlier shorter pick must not save later.
local function closePendingPrompt()
  if type(_G.StaticPopup_Hide) == "function" then
    _G.StaticPopup_Hide(RetentionRow.CONFIRM_DIALOG)
  end
end

-- Without the popup API nothing is confirmed, so nothing is deleted.
local function confirmShorter(prompt, label, language, onAccept)
  if type(_G.StaticPopup_Show) ~= "function" then
    return
  end
  _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
  _G.StaticPopupDialogs[RetentionRow.CONFIRM_DIALOG] = {
    text = string.format(Localization.Text(prompt, language), label),
    -- The game's own localized labels.
    button1 = rawget(_G, "ACCEPT") or Localization.Text("Accept", language),
    button2 = rawget(_G, "CANCEL") or Localization.Text("Cancel", language),
    OnAccept = onAccept,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }
  _G.StaticPopup_Show(RetentionRow.CONFIRM_DIALOG)
end

-- options: { language, initial (seconds), onChange(seconds), rowWidth, labelSpacing, colors }
-- Returns the DropdownSelector handle plus setLanguage(language), and
-- confirmReset(resetPage) and resetToDefault(onChange) for the panel's
-- Reset to Defaults button.
function RetentionRow.Create(factory, parent, options)
  local language = options.language
  local current = type(options.initial) == "number" and options.initial or RetentionRow.DEFAULT_SECONDS
  local control

  local function save(seconds)
    current = seconds
    control.setSelected(seconds)
    options.onChange(seconds)
  end

  -- A shorter age deletes older history at once, so it asks first. The
  -- dropdown goes back to the saved value and only moves on Accept.
  local function choose(seconds)
    if seconds >= current then
      closePendingPrompt()
      save(seconds)
      return
    end
    control.setSelected(current)
    confirmShorter(CONFIRM_PROMPT, labelFor(seconds, language, current), language, function()
      save(seconds)
    end)
  end

  control = DropdownSelector.Create(factory, parent, {
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
    onChange = choose,
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

  -- Reset to Defaults deletes older history too when the default is
  -- shorter, so it asks first; resetPage runs on Accept, or at once when
  -- nothing would be deleted. Cancel resets nothing on the page.
  function control.confirmReset(resetPage)
    closePendingPrompt()
    local default = RetentionRow.DEFAULT_SECONDS
    if default >= current then
      resetPage()
      return
    end
    confirmShorter(CONFIRM_RESET_PROMPT, labelFor(default, language, current), language, resetPage)
  end

  function control.resetToDefault(onChange)
    closePendingPrompt()
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
