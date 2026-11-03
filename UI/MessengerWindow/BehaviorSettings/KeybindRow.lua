local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local KeybindOpener = ns.MessengerWindowBehaviorKeybindOpener or require("WhisperMessenger.UI.MessengerWindow.BehaviorSettings.KeybindOpener")

-- Behavior page row: the current open/close key and a "Set keybind…" button
-- that opens the game's Key Bindings screen. The button is disabled with a
-- reason in combat and on clients that can't open that screen.
local KeybindRow = {}

local ROW_GAP = 8
local REFRESH_EVENTS = { "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS" }

local function text(key)
  return Localization.Text(key)
end

local function closeMessenger()
  local runtime = ns.Bootstrap and ns.Bootstrap.runtime
  if runtime and type(runtime.setWindowVisible) == "function" then
    runtime.setWindowVisible(false)
  end
end

local function keyStatusText()
  return string.format(text("Open/close: %s"), KeybindOpener.CurrentKeysText() or text("Not bound"))
end

-- options = { panel }. Returns { row, bottom, refresh, setLanguage,
-- refreshTheme }; the next control anchors below `bottom`.
function KeybindRow.Create(factory, frame, anchor, options)
  local row = factory.CreateFrame("Frame", nil, frame)
  row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_SLIDER_ROW_SPACING)
  row:SetSize(Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, Theme.LAYOUT.OPTION_BUTTON_HEIGHT * 2 + ROW_GAP)

  local status = row:CreateFontString(nil, "OVERLAY", Theme.FONTS.icon_label)
  status:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  status:SetJustifyH("LEFT")

  local button = options.panel:bind(
    UIHelpers.createOptionButton(
      factory,
      row,
      text("Set keybind…"),
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH }
    ),
    { type = "optionButton" }
  )
  button:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -ROW_GAP)
  local availability = UIHelpers.attachDisabledState(factory, button)

  local function refresh()
    status:SetText(keyStatusText())
    local enabled, reasonKey = KeybindOpener.Availability()
    availability.set(enabled, reasonKey and text(reasonKey))
  end

  button:SetScript("OnClick", function()
    if availability.isEnabled() then
      KeybindOpener.Open(closeMessenger)
    end
  end)

  for _, event in ipairs(REFRESH_EVENTS) do
    row:RegisterEvent(event)
  end
  row:SetScript("OnEvent", refresh)
  row:SetScript("OnShow", refresh)

  local function refreshTheme()
    UIHelpers.setTextColor(status, Theme.COLORS.text_secondary)
  end

  refresh()
  refreshTheme()

  return {
    row = row,
    bottom = button,
    refresh = refresh,
    refreshTheme = refreshTheme,
    setLanguage = function()
      button.label:SetText(text("Set keybind…"))
      refresh()
    end,
  }
end

ns.MessengerWindowBehaviorKeybindRow = KeybindRow
return KeybindRow
