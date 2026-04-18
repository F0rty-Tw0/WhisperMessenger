local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")

local BehaviorSettings = {}

local PADDING = Theme.CONTENT_PADDING

local DEFAULTS = {
  dimWhenMoving = true,
  autoFocusComposer = false,
  hideFromDefaultChat = false,
  autoOpenIncoming = false,
  autoOpenOutgoing = false,
  doubleEscapeToClose = false,
}

function BehaviorSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local title = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  title:SetText("Behavior")
  UIHelpers.setTextColor(title, Theme.COLORS.text_primary)

  local hint = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  hint:SetText("Control how the messenger window behaves.")
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

  local profanityEnabled = _G.GetCVar and _G.GetCVar("profanityFilter") == "1" or false

  local toggleSpecs = {
    {
      label = "Dim when moving",
      initial = config.dimWhenMoving ~= false,
      onChange = function(value)
        onChange("dimWhenMoving", value)
      end,
      tooltipLines = {
        "Dim when moving",
        "Reduces window opacity while your character is moving.",
      },
      anchorOffsetY = -24,
    },
    {
      label = "Auto-focus chat input",
      initial = config.autoFocusComposer == true,
      onChange = function(value)
        onChange("autoFocusComposer", value)
      end,
      tooltipLines = {
        "Auto-focus chat input",
        "Places the cursor in the text box when you open the messenger.",
      },
    },
    {
      label = "Hide whispers from default chat",
      initial = config.hideFromDefaultChat == true,
      onChange = function(value)
        onChange("hideFromDefaultChat", value)
      end,
      tooltipLines = {
        "Hide whispers from default chat",
        "Prevents whisper messages from appearing in the default WoW chat frame.",
        " ",
        "|cffff8080Note:|r In Mythic+ content, Blizzard's /r reply and R-keybind may fail while this is enabled (WoW 12.0 secret-value taint on chatEditLastTell). Use |cffffff00/wr|r (or bind /wr to R via macro) to reply safely.",
      },
    },
    {
      label = "Enable profanity filter",
      initial = profanityEnabled,
      onChange = function(value)
        if _G.SetCVar then
          _G.SetCVar("profanityFilter", value and "1" or "0")
        end
      end,
      tooltipLines = {
        "Enable profanity filter",
        "Uses Blizzard's built-in filter to censor profanity in messages.",
      },
    },
    {
      label = "Auto-open on incoming whisper",
      initial = config.autoOpenIncoming == true,
      onChange = function(value)
        onChange("autoOpenIncoming", value)
      end,
      tooltipLines = {
        "Auto-open on incoming whisper",
        "Opens the messenger when you receive a whisper. Disabled during combat.",
      },
    },
    {
      label = "Auto-open on outgoing whisper",
      initial = config.autoOpenOutgoing == true,
      onChange = function(value)
        onChange("autoOpenOutgoing", value)
      end,
      tooltipLines = {
        "Auto-open on outgoing whisper",
        "Opens the messenger when you send a whisper, press Reply, or whisper from the friends list. Disabled during combat.",
      },
    },
    {
      label = "Double ESC to close",
      initial = config.doubleEscapeToClose == true,
      onChange = function(value)
        onChange("doubleEscapeToClose", value)
      end,
      tooltipLines = {
        "Double ESC to close",
        "First Esc clears the chat input; second Esc closes the window.",
      },
    },
  }

  local toggles = SettingsControls.BuildToggleList(factory, frame, hint, toggleSpecs)
  local dimToggle = toggles[1]
  local autoFocusToggle = toggles[2]
  local hideFromDefaultChatToggle = toggles[3]
  local profanityFilterToggle = toggles[4]
  local autoOpenIncomingToggle = toggles[5]
  local autoOpenOutgoingToggle = toggles[6]
  local doubleEscapeToggle = toggles[7]

  local normalColors = SettingsControls.OptionButtonColors(Theme)
  local resetButton = UIHelpers.createOptionButton(
    factory,
    frame,
    "Reset to Defaults",
    normalColors,
    { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH }
  )
  resetButton:SetPoint("TOPLEFT", doubleEscapeToggle.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    dimToggle.setValue(DEFAULTS.dimWhenMoving)
    onChange("dimWhenMoving", DEFAULTS.dimWhenMoving)
    autoFocusToggle.setValue(DEFAULTS.autoFocusComposer)
    onChange("autoFocusComposer", DEFAULTS.autoFocusComposer)
    hideFromDefaultChatToggle.setValue(DEFAULTS.hideFromDefaultChat)
    onChange("hideFromDefaultChat", DEFAULTS.hideFromDefaultChat)
    autoOpenIncomingToggle.setValue(DEFAULTS.autoOpenIncoming)
    onChange("autoOpenIncoming", DEFAULTS.autoOpenIncoming)
    autoOpenOutgoingToggle.setValue(DEFAULTS.autoOpenOutgoing)
    onChange("autoOpenOutgoing", DEFAULTS.autoOpenOutgoing)
    doubleEscapeToggle.setValue(DEFAULTS.doubleEscapeToClose)
    onChange("doubleEscapeToClose", DEFAULTS.doubleEscapeToClose)
    profanityFilterToggle.setValue(true)
    if _G.SetCVar then
      _G.SetCVar("profanityFilter", "1")
    end
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    UIHelpers.setTextColor(title, activeTheme.COLORS.text_primary)
    UIHelpers.setTextColor(hint, activeTheme.COLORS.text_secondary)

    local activeToggleColors = SettingsControls.ToggleColors(activeTheme)
    for _, toggle in ipairs(toggles) do
      toggle.applyThemeColors(activeToggleColors)
    end

    if resetButton.applyThemeColors then
      resetButton.applyThemeColors(SettingsControls.OptionButtonColors(activeTheme))
    end
  end

  refreshTheme(Theme)

  local function refreshLayout(width)
    if type(width) ~= "number" or width <= 0 then
      return
    end
    local maxWidth = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH
    local effective = math.min(maxWidth, math.max(160, math.floor(width)))
    if hint.SetWidth then
      hint:SetWidth(effective)
    end
    for _, toggle in ipairs(toggles) do
      toggle.setWidth(effective)
    end
    if resetButton.setWidth then
      resetButton.setWidth(effective)
    end
  end

  return {
    frame = frame,
    refreshLayout = refreshLayout,
    dimToggle = dimToggle,
    autoFocusToggle = autoFocusToggle,
    hideFromDefaultChatToggle = hideFromDefaultChatToggle,
    profanityFilterToggle = profanityFilterToggle,
    autoOpenIncomingToggle = autoOpenIncomingToggle,
    autoOpenOutgoingToggle = autoOpenOutgoingToggle,
    doubleEscapeToggle = doubleEscapeToggle,
    resetButton = resetButton,
    refreshTheme = refreshTheme,
  }
end

ns.BehaviorSettings = BehaviorSettings
return BehaviorSettings
