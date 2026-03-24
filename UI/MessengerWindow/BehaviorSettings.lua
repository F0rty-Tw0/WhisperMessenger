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
}

function BehaviorSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function() end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  title:SetText("Behavior")
  UIHelpers.setTextColor(title, Theme.COLORS.text_primary)

  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  hint:SetText("Control how the messenger window behaves.")
  UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)

  local toggleColors = {
    text = Theme.COLORS.text_primary,
    on = Theme.COLORS.online,
    off = Theme.COLORS.offline,
  }
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
    end
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

  -- Reset button
  local normalColors = {
    bg = Theme.COLORS.option_button_bg,
    bgHover = Theme.COLORS.option_button_hover,
    text = Theme.COLORS.option_button_text,
    textHover = Theme.COLORS.option_button_text_hover,
  }
  local resetButton = UIHelpers.createOptionButton(
    factory,
    frame,
    "Reset to Defaults",
    normalColors,
    { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = TOGGLE_WIDTH }
  )
  resetButton:SetPoint("TOPLEFT", autoSelectToggle.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    dimToggle.setValue(DEFAULTS.dimWhenMoving)
    onChange("dimWhenMoving", DEFAULTS.dimWhenMoving)
    autoFocusToggle.setValue(DEFAULTS.autoFocusComposer)
    onChange("autoFocusComposer", DEFAULTS.autoFocusComposer)
    autoSelectToggle.setValue(DEFAULTS.autoSelectUnread)
    onChange("autoSelectUnread", DEFAULTS.autoSelectUnread)
  end)

  return {
    frame = frame,
    dimToggle = dimToggle,
    autoFocusToggle = autoFocusToggle,
    autoSelectToggle = autoSelectToggle,
    resetButton = resetButton,
  }
end

ns.BehaviorSettings = BehaviorSettings
return BehaviorSettings
