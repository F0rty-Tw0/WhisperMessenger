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
  showGroupChats = true,
}

function BehaviorSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function(...)
    local _ = ...
  end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local header = SettingsControls.CreateHeader(frame, {
    title = "Behavior",
    hint = "Control how the messenger window behaves.",
  })
  local hint = header.hint

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
    {
      label = "Show group chats",
      initial = config.showGroupChats ~= false,
      onChange = function(value)
        onChange("showGroupChats", value)
      end,
      tooltipLines = {
        "Show group chats",
        "Shows a Groups tab in the contacts list with party, instance, and Battle.net group conversations.",
        "When off, only whispers appear.",
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
  local showGroupChatsToggle = toggles[8]

  local panel = SettingsControls.NewPanelRegistry()
  panel:bind(dimToggle, { type = "toggle", key = "dimWhenMoving", default = DEFAULTS.dimWhenMoving })
  panel:bind(autoFocusToggle, { type = "toggle", key = "autoFocusComposer", default = DEFAULTS.autoFocusComposer })
  panel:bind(hideFromDefaultChatToggle, { type = "toggle", key = "hideFromDefaultChat", default = DEFAULTS.hideFromDefaultChat })
  -- Profanity filter writes a CVar instead of routing through onChange.
  panel:bind(profanityFilterToggle, {
    type = "toggle",
    reset = function(control)
      control.setValue(true)
      if _G.SetCVar then
        _G.SetCVar("profanityFilter", "1")
      end
    end,
  })
  panel:bind(autoOpenIncomingToggle, { type = "toggle", key = "autoOpenIncoming", default = DEFAULTS.autoOpenIncoming })
  panel:bind(autoOpenOutgoingToggle, { type = "toggle", key = "autoOpenOutgoing", default = DEFAULTS.autoOpenOutgoing })
  panel:bind(doubleEscapeToggle, { type = "toggle", key = "doubleEscapeToClose", default = DEFAULTS.doubleEscapeToClose })
  panel:bind(showGroupChatsToggle, { type = "toggle", key = "showGroupChats", default = DEFAULTS.showGroupChats })

  local resetButton = panel:bind(
    UIHelpers.createOptionButton(
      factory,
      frame,
      "Reset to Defaults",
      SettingsControls.OptionButtonColors(Theme),
      { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH }
    ),
    { type = "optionButton" }
  )
  resetButton:SetPoint("TOPLEFT", showGroupChatsToggle.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    panel:reset(onChange)
  end)

  local bottomSpacer = factory.CreateFrame("Frame", nil, frame)
  bottomSpacer:SetSize(1, PADDING)
  bottomSpacer:SetPoint("TOPLEFT", resetButton, "BOTTOMLEFT", 0, 0)
  -- Marker the options scrollview reads to size the scroll content to this
  -- tab's actual extent. Anchored to the very last control plus a padding
  -- spacer, so its bottom = panel content bottom.
  frame._wmBottomMarker = bottomSpacer

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    header.refreshTheme(activeTheme)
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
    dimToggle = dimToggle,
    autoFocusToggle = autoFocusToggle,
    hideFromDefaultChatToggle = hideFromDefaultChatToggle,
    profanityFilterToggle = profanityFilterToggle,
    autoOpenIncomingToggle = autoOpenIncomingToggle,
    autoOpenOutgoingToggle = autoOpenOutgoingToggle,
    doubleEscapeToggle = doubleEscapeToggle,
    showGroupChatsToggle = showGroupChatsToggle,
    resetButton = resetButton,
    refreshTheme = refreshTheme,
  }
end

ns.BehaviorSettings = BehaviorSettings
return BehaviorSettings
