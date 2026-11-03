local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local ButtonSelector = ns.MessengerWindowButtonSelector or require("WhisperMessenger.UI.MessengerWindow.AppearanceSettings.ButtonSelector")
local ToastStack = ns.WhisperToastsToastStack or require("WhisperMessenger.UI.WhisperToasts.ToastStack")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

-- The "Show pop-up cards" switch and the corner picker under it. The picker
-- stays visible but disabled (value kept) while cards are off.
local ToastControls = {}

ToastControls.DEFAULTS = {
  showWhisperToasts = false,
  whisperToastCorner = ToastStack.DEFAULT_CORNER,
}

local DEFAULTS = ToastControls.DEFAULTS

local CORNER_SPECS = {
  { key = "TOPLEFT", label = "Top left" },
  { key = "TOPRIGHT", label = "Top right" },
  { key = "BOTTOMLEFT", label = "Bottom left" },
  { key = "BOTTOMRIGHT", label = "Bottom right" },
}

local function text(key)
  return Localization.Text(key)
end

local function cornerOptions()
  local options = {}
  for _, spec in ipairs(CORNER_SPECS) do
    options[#options + 1] = { key = spec.key, label = text(spec.label) }
  end
  return options
end

-- options: panel (registry), anchor (row above), onChange, rowSpacing.
-- Returns { row (the last row), onReset(key, value), setLanguage() }.
function ToastControls.Create(factory, frame, config, options)
  local panel = options.panel
  local onChange = options.onChange
  local enabled = config.showWhisperToasts == true
  local position

  local function refreshAvailability()
    position.availability.set(enabled, not enabled and text("Turn on pop-up cards to pick where they appear.") or nil)
  end

  local toggle = panel:bind(
    UIHelpers.createToggleRow(
      factory,
      frame,
      text("Show pop-up cards"),
      enabled,
      SettingsControls.ToggleColors(Theme),
      { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 },
      function(value)
        enabled = value == true
        refreshAvailability()
        onChange("showWhisperToasts", value)
      end,
      {
        text("Show pop-up cards"),
        text("While the messenger is closed, shows a small card for each new whisper. Click a card to open that chat."),
      }
    ),
    { type = "toggle", key = "showWhisperToasts", default = DEFAULTS.showWhisperToasts }
  )
  toggle.row:SetPoint("TOPLEFT", options.anchor, "BOTTOMLEFT", 0, options.rowSpacing)

  position = panel:bind(
    ButtonSelector.Create(factory, frame, {
      labelText = text("Pop-up card position"),
      optionsList = cornerOptions(),
      fallbackKey = DEFAULTS.whisperToastCorner,
      initial = config.whisperToastCorner or DEFAULTS.whisperToastCorner,
      colors = SettingsControls.SelectorColors(Theme),
      onChange = function(value)
        onChange("whisperToastCorner", value)
      end,
      rowWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH,
      labelSpacing = Theme.LAYOUT.SETTINGS_LABEL_SPACING,
      buttonHeight = 26,
      buttonSpacing = 4,
      maxPerRow = 2,
    }),
    { type = "selector", key = "whisperToastCorner", default = DEFAULTS.whisperToastCorner }
  )
  position.row:SetPoint("TOPLEFT", toggle.row, "BOTTOMLEFT", 0, options.rowSpacing)
  position.availability = UIHelpers.attachDisabledState(factory, position.row)
  refreshAvailability()

  local controls = { row = position.row }

  -- The panel's reset writes defaults through onChange, not the switch's callback.
  function controls.onReset(key, value)
    if key == "showWhisperToasts" then
      enabled = value == true
      refreshAvailability()
    end
  end

  function controls.setLanguage()
    toggle.label:SetText(text("Show pop-up cards"))
    position.label:SetText(text("Pop-up card position"))
    position.setOptionsList(cornerOptions())
    refreshAvailability()
  end

  return controls
end

ns.NotificationSettingsToastControls = ToastControls
return ToastControls
