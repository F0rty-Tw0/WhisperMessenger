local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local BehaviorSettings = {}

local PADDING = Theme.CONTENT_PADDING

local DEFAULTS = {
  dimWhenMoving = true,
  autoFocusComposer = false,
  autoSelectUnread = true,
  hideFromDefaultChat = false,
  autoOpenIncoming = false,
  autoOpenOutgoing = false,
  scrollToLatestOnOpen = true,
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

  local function toggleColorsFor(activeTheme)
    return {
      text = activeTheme.COLORS.text_primary,
      on = activeTheme.COLORS.option_toggle_on or activeTheme.COLORS.online,
      off = activeTheme.COLORS.option_toggle_off or activeTheme.COLORS.offline,
      border = activeTheme.COLORS.option_toggle_border or activeTheme.COLORS.divider,
    }
  end
  local toggleColors = toggleColorsFor(Theme)
  local toggleLayout = { width = Theme.LAYOUT.SETTINGS_CONTROL_WIDTH, height = 24 }

  local dimToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Dim when moving",
    config.dimWhenMoving ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("dimWhenMoving", value)
    end,
    {
      "Dim when moving",
      "Reduces window opacity while your character is moving.",
    }
  )
  dimToggle.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -24)

  local autoFocusToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Auto-focus chat input",
    config.autoFocusComposer == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("autoFocusComposer", value)
    end,
    {
      "Auto-focus chat input",
      "Places the cursor in the text box when you open the messenger.",
    }
  )
  autoFocusToggle.row:SetPoint("TOPLEFT", dimToggle.row, "BOTTOMLEFT", 0, -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING)

  local autoSelectToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Jump to unread on open",
    config.autoSelectUnread ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("autoSelectUnread", value)
    end,
    {
      "Jump to unread on open",
      "Selects the most recent contact with unread messages when you open the messenger.",
    }
  )
  autoSelectToggle.row:SetPoint(
    "TOPLEFT",
    autoFocusToggle.row,
    "BOTTOMLEFT",
    0,
    -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
  )

  local hideFromDefaultChatToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Hide whispers from default chat",
    config.hideFromDefaultChat == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("hideFromDefaultChat", value)
    end,
    {
      "Hide whispers from default chat",
      "Prevents whisper messages from appearing in the default WoW chat frame.",
      " ",
      "|cffff8080Note:|r In Mythic+ content, Blizzard's /r reply and R-keybind may fail while this is enabled (WoW 12.0 secret-value taint on chatEditLastTell). Use |cffffff00/wr|r (or bind /wr to R via macro) to reply safely.",
    }
  )
  hideFromDefaultChatToggle.row:SetPoint(
    "TOPLEFT",
    autoSelectToggle.row,
    "BOTTOMLEFT",
    0,
    -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
  )

  local profanityEnabled = _G.GetCVar and _G.GetCVar("profanityFilter") == "1" or false
  local profanityFilterToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Enable profanity filter",
    profanityEnabled,
    toggleColors,
    toggleLayout,
    function(value)
      if _G.SetCVar then
        _G.SetCVar("profanityFilter", value and "1" or "0")
      end
    end,
    {
      "Enable profanity filter",
      "Uses Blizzard's built-in filter to censor profanity in messages.",
    }
  )
  profanityFilterToggle.row:SetPoint(
    "TOPLEFT",
    hideFromDefaultChatToggle.row,
    "BOTTOMLEFT",
    0,
    -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
  )

  local autoOpenIncomingToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Auto-open on incoming whisper",
    config.autoOpenIncoming == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("autoOpenIncoming", value)
    end,
    {
      "Auto-open on incoming whisper",
      "Opens the messenger when you receive a whisper. Disabled during combat.",
    }
  )
  autoOpenIncomingToggle.row:SetPoint(
    "TOPLEFT",
    profanityFilterToggle.row,
    "BOTTOMLEFT",
    0,
    -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
  )

  local autoOpenOutgoingToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Auto-open on outgoing whisper",
    config.autoOpenOutgoing == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("autoOpenOutgoing", value)
    end,
    {
      "Auto-open on outgoing whisper",
      "Opens the messenger when you send a whisper, press Reply, or whisper from the friends list. Disabled during combat.",
    }
  )
  autoOpenOutgoingToggle.row:SetPoint(
    "TOPLEFT",
    autoOpenIncomingToggle.row,
    "BOTTOMLEFT",
    0,
    -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
  )

  local scrollToLatestToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Scroll to latest on open",
    config.scrollToLatestOnOpen ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("scrollToLatestOnOpen", value)
    end,
    {
      "Scroll to latest on open",
      "Automatically scrolls to the most recent message when you open the messenger.",
    }
  )
  scrollToLatestToggle.row:SetPoint(
    "TOPLEFT",
    autoOpenOutgoingToggle.row,
    "BOTTOMLEFT",
    0,
    -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
  )

  local doubleEscapeToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Double ESC to close",
    config.doubleEscapeToClose == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("doubleEscapeToClose", value)
    end,
    {
      "Double ESC to close",
      "First Esc clears the chat input; second Esc closes the window.",
    }
  )
  doubleEscapeToggle.row:SetPoint(
    "TOPLEFT",
    scrollToLatestToggle.row,
    "BOTTOMLEFT",
    0,
    -Theme.LAYOUT.SETTINGS_TOGGLE_ROW_SPACING
  )

  -- Reset button
  local function optionButtonColorsFor(activeTheme)
    return {
      bg = activeTheme.COLORS.option_button_bg,
      bgHover = activeTheme.COLORS.option_button_hover,
      text = activeTheme.COLORS.option_button_text,
      textHover = activeTheme.COLORS.option_button_text_hover,
    }
  end
  local normalColors = optionButtonColorsFor(Theme)
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
    autoSelectToggle.setValue(DEFAULTS.autoSelectUnread)
    onChange("autoSelectUnread", DEFAULTS.autoSelectUnread)
    hideFromDefaultChatToggle.setValue(DEFAULTS.hideFromDefaultChat)
    onChange("hideFromDefaultChat", DEFAULTS.hideFromDefaultChat)
    autoOpenIncomingToggle.setValue(DEFAULTS.autoOpenIncoming)
    onChange("autoOpenIncoming", DEFAULTS.autoOpenIncoming)
    autoOpenOutgoingToggle.setValue(DEFAULTS.autoOpenOutgoing)
    onChange("autoOpenOutgoing", DEFAULTS.autoOpenOutgoing)
    scrollToLatestToggle.setValue(DEFAULTS.scrollToLatestOnOpen)
    onChange("scrollToLatestOnOpen", DEFAULTS.scrollToLatestOnOpen)
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

    local activeToggleColors = toggleColorsFor(activeTheme)
    dimToggle.applyThemeColors(activeToggleColors)
    autoFocusToggle.applyThemeColors(activeToggleColors)
    autoSelectToggle.applyThemeColors(activeToggleColors)
    hideFromDefaultChatToggle.applyThemeColors(activeToggleColors)
    profanityFilterToggle.applyThemeColors(activeToggleColors)
    autoOpenIncomingToggle.applyThemeColors(activeToggleColors)
    autoOpenOutgoingToggle.applyThemeColors(activeToggleColors)
    scrollToLatestToggle.applyThemeColors(activeToggleColors)
    doubleEscapeToggle.applyThemeColors(activeToggleColors)

    if resetButton.applyThemeColors then
      resetButton.applyThemeColors(optionButtonColorsFor(activeTheme))
    end
  end

  refreshTheme(Theme)

  return {
    frame = frame,
    dimToggle = dimToggle,
    autoFocusToggle = autoFocusToggle,
    autoSelectToggle = autoSelectToggle,
    hideFromDefaultChatToggle = hideFromDefaultChatToggle,
    profanityFilterToggle = profanityFilterToggle,
    autoOpenIncomingToggle = autoOpenIncomingToggle,
    autoOpenOutgoingToggle = autoOpenOutgoingToggle,
    scrollToLatestToggle = scrollToLatestToggle,
    doubleEscapeToggle = doubleEscapeToggle,
    resetButton = resetButton,
    refreshTheme = refreshTheme,
  }
end

ns.BehaviorSettings = BehaviorSettings
return BehaviorSettings
