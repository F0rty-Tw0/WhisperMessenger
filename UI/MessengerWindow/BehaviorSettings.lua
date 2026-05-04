local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SettingsControls = ns.SettingsControls or require("WhisperMessenger.UI.Shared.SettingsControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")

local BehaviorSettings = {}

local PADDING = Theme.CONTENT_PADDING

local function text(key)
  return Localization.Text(key)
end

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
    title = text("Behavior"),
    hint = text("Control how the messenger window behaves."),
  })
  local hint = header.hint

  local profanityEnabled = _G.GetCVar and _G.GetCVar("profanityFilter") == "1" or false

  local toggleSpecs = {
    {
      label = text("Dim when moving"),
      initial = config.dimWhenMoving ~= false,
      onChange = function(value)
        onChange("dimWhenMoving", value)
      end,
      tooltipLines = {
        text("Dim when moving"),
        text("Reduces window opacity while your character is moving."),
      },
      anchorOffsetY = -24,
    },
    {
      label = text("Auto-focus chat input"),
      initial = config.autoFocusComposer == true,
      onChange = function(value)
        onChange("autoFocusComposer", value)
      end,
      tooltipLines = {
        text("Auto-focus chat input"),
        text("Places the cursor in the text box when you open the messenger."),
      },
    },
    {
      label = text("Hide whispers from default chat"),
      initial = config.hideFromDefaultChat == true,
      onChange = function(value)
        onChange("hideFromDefaultChat", value)
      end,
      tooltipLines = {
        text("Hide whispers from default chat"),
        text("Prevents whisper messages from appearing in the default WoW chat frame."),
        " ",
        text(
          "|cffff8080Note:|r In Mythic+ content, Blizzard's /r reply and R-keybind may fail while this is enabled (WoW 12.0 secret-value taint on chatEditLastTell). Use |cffffff00/wr|r (or bind /wr to R via macro) to reply safely."
        ),
      },
    },
    {
      label = text("Enable profanity filter"),
      initial = profanityEnabled,
      onChange = function(value)
        if _G.SetCVar then
          _G.SetCVar("profanityFilter", value and "1" or "0")
        end
      end,
      tooltipLines = {
        text("Enable profanity filter"),
        text("Uses Blizzard's built-in filter to censor profanity in messages."),
      },
    },
    {
      label = text("Auto-open on incoming whisper"),
      initial = config.autoOpenIncoming == true,
      onChange = function(value)
        onChange("autoOpenIncoming", value)
      end,
      tooltipLines = {
        text("Auto-open on incoming whisper"),
        text("Opens the messenger when you receive a whisper. Disabled during combat."),
      },
    },
    {
      label = text("Auto-open on outgoing whisper"),
      initial = config.autoOpenOutgoing == true,
      onChange = function(value)
        onChange("autoOpenOutgoing", value)
      end,
      tooltipLines = {
        text("Auto-open on outgoing whisper"),
        text("Opens the messenger when you send a whisper, press Reply, or whisper from the friends list. Disabled during combat."),
      },
    },
    {
      label = text("Double ESC to close"),
      initial = config.doubleEscapeToClose == true,
      onChange = function(value)
        onChange("doubleEscapeToClose", value)
      end,
      tooltipLines = {
        text("Double ESC to close"),
        text("First Esc clears the chat input; second Esc closes the window."),
      },
    },
    {
      label = text("Show group chats"),
      initial = config.showGroupChats ~= false,
      onChange = function(value)
        onChange("showGroupChats", value)
      end,
      tooltipLines = {
        text("Show group chats"),
        text("Shows a Groups tab in the contacts list with party, instance, and Battle.net group conversations."),
        text("When off, only whispers appear."),
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
      text("Reset to Defaults"),
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

  local function setLanguage()
    header.title:SetText(text("Behavior"))
    header.hint:SetText(text("Control how the messenger window behaves."))
    dimToggle.label:SetText(text("Dim when moving"))
    autoFocusToggle.label:SetText(text("Auto-focus chat input"))
    hideFromDefaultChatToggle.label:SetText(text("Hide whispers from default chat"))
    profanityFilterToggle.label:SetText(text("Enable profanity filter"))
    autoOpenIncomingToggle.label:SetText(text("Auto-open on incoming whisper"))
    autoOpenOutgoingToggle.label:SetText(text("Auto-open on outgoing whisper"))
    doubleEscapeToggle.label:SetText(text("Double ESC to close"))
    showGroupChatsToggle.label:SetText(text("Show group chats"))
    resetButton.label:SetText(text("Reset to Defaults"))
    -- Tooltip lines were captured into closure-frozen arrays at construction
    -- and stay in the previous language until the toggle is re-hovered after
    -- a /reload. Live-refreshing them would require restructuring the toggle
    -- helper to read keys at hover time; deferred until the codebase needs it.
  end

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
    setLanguage = setLanguage,
  }
end

ns.BehaviorSettings = BehaviorSettings
return BehaviorSettings
