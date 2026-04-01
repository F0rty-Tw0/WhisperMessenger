local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local BehaviorSettings = {}

local PADDING = Theme.CONTENT_PADDING
local TOGGLE_WIDTH = 280
local ROW_SPACING = 16

local DEFAULTS = {
  dimWhenMoving = true,
  autoFocusComposer = false,
  autoSelectUnread = true,
  hideFromDefaultChat = false,
  autoOpenWindow = false,
}

function BehaviorSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function() end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local title = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  title:SetText("Behavior")
  UIHelpers.setTextColor(title, Theme.COLORS.text_primary)

  local hint = frame:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  hint:SetText("Control how the messenger window behaves.")
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
  local toggleLayout = { width = TOGGLE_WIDTH, height = 24 }

  local dimToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Dim when moving",
    config.dimWhenMoving ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("dimWhenMoving", value)
    end
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
  autoFocusToggle.row:SetPoint("TOPLEFT", dimToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local autoSelectToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Auto-select unread on open",
    config.autoSelectUnread ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("autoSelectUnread", value)
    end
  )
  autoSelectToggle.row:SetPoint("TOPLEFT", autoFocusToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local hideFromDefaultChatToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Hide whispers from default chat",
    config.hideFromDefaultChat == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("hideFromDefaultChat", value)
    end
  )
  hideFromDefaultChatToggle.row:SetPoint("TOPLEFT", autoSelectToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

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
    end
  )
  profanityFilterToggle.row:SetPoint("TOPLEFT", hideFromDefaultChatToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local autoOpenWindowToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Auto-open on whisper",
    config.autoOpenWindow == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("autoOpenWindow", value)
    end,
    {
      "Auto-open on whisper",
      "Opens the messenger when you receive a whisper, press Reply, or whisper from the friends list. Disabled during combat.",
    }
  )
  autoOpenWindowToggle.row:SetPoint("TOPLEFT", profanityFilterToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

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
    { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = TOGGLE_WIDTH }
  )
  resetButton:SetPoint("TOPLEFT", autoOpenWindowToggle.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    dimToggle.setValue(DEFAULTS.dimWhenMoving)
    onChange("dimWhenMoving", DEFAULTS.dimWhenMoving)
    autoFocusToggle.setValue(DEFAULTS.autoFocusComposer)
    onChange("autoFocusComposer", DEFAULTS.autoFocusComposer)
    autoSelectToggle.setValue(DEFAULTS.autoSelectUnread)
    onChange("autoSelectUnread", DEFAULTS.autoSelectUnread)
    hideFromDefaultChatToggle.setValue(DEFAULTS.hideFromDefaultChat)
    onChange("hideFromDefaultChat", DEFAULTS.hideFromDefaultChat)
    autoOpenWindowToggle.setValue(DEFAULTS.autoOpenWindow)
    onChange("autoOpenWindow", DEFAULTS.autoOpenWindow)
    profanityFilterToggle.setValue(true)
    if _G.SetCVar then
      _G.SetCVar("profanityFilter", "1")
    end
  end)

  local function refreshTheme(activeTheme)
    activeTheme = activeTheme or Theme
    UIHelpers.setTextColor(title, activeTheme.COLORS.text_primary)
    UIHelpers.setTextColor(hint, activeTheme.COLORS.text_secondary)

    local toggleColors = toggleColorsFor(activeTheme)
    dimToggle.applyThemeColors(toggleColors)
    autoFocusToggle.applyThemeColors(toggleColors)
    autoSelectToggle.applyThemeColors(toggleColors)
    hideFromDefaultChatToggle.applyThemeColors(toggleColors)
    profanityFilterToggle.applyThemeColors(toggleColors)
    autoOpenWindowToggle.applyThemeColors(toggleColors)

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
    autoOpenWindowToggle = autoOpenWindowToggle,
    resetButton = resetButton,
    refreshTheme = refreshTheme,
  }
end

ns.BehaviorSettings = BehaviorSettings
return BehaviorSettings
