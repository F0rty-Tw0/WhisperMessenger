local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local NotificationSettings = {}

local PADDING = Theme.CONTENT_PADDING
local TOGGLE_WIDTH = 280
local ROW_SPACING = 16

local DEFAULTS = {
  badgePulse = true,
  playSoundOnWhisper = false,
  showUnreadBadge = true,
}

function NotificationSettings.Create(factory, parent, config, options)
  local onChange = options.onChange or function() end

  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetAllPoints(parent)

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  title:SetPoint("TOPLEFT", frame, "TOPLEFT", PADDING, -PADDING)
  title:SetText("Notifications")
  UIHelpers.setTextColor(title, Theme.COLORS.text_primary)

  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  hint:SetText("Configure alerts for incoming messages.")
  UIHelpers.setTextColor(hint, Theme.COLORS.text_secondary)

  local toggleColors = {
    text = Theme.COLORS.text_primary,
    on = Theme.COLORS.online,
    off = Theme.COLORS.offline,
  }
  local toggleLayout = { width = TOGGLE_WIDTH, height = 24 }

  local badgePulseToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Badge pulse animation",
    config.badgePulse ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("badgePulse", value)
    end
  )
  badgePulseToggle.row:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -24)

  local playSoundToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Notification sound",
    config.playSoundOnWhisper == true,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("playSoundOnWhisper", value)
    end
  )
  playSoundToggle.row:SetPoint("TOPLEFT", badgePulseToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

  local showBadgeToggle = UIHelpers.createToggleRow(
    factory,
    frame,
    "Show unread badge",
    config.showUnreadBadge ~= false,
    toggleColors,
    toggleLayout,
    function(value)
      onChange("showUnreadBadge", value)
    end
  )
  showBadgeToggle.row:SetPoint("TOPLEFT", playSoundToggle.row, "BOTTOMLEFT", 0, -ROW_SPACING)

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
  resetButton:SetPoint("TOPLEFT", showBadgeToggle.row, "BOTTOMLEFT", 0, -24)
  resetButton:SetScript("OnClick", function()
    badgePulseToggle.setValue(DEFAULTS.badgePulse)
    onChange("badgePulse", DEFAULTS.badgePulse)
    playSoundToggle.setValue(DEFAULTS.playSoundOnWhisper)
    onChange("playSoundOnWhisper", DEFAULTS.playSoundOnWhisper)
    showBadgeToggle.setValue(DEFAULTS.showUnreadBadge)
    onChange("showUnreadBadge", DEFAULTS.showUnreadBadge)
  end)

  return {
    frame = frame,
    badgePulseToggle = badgePulseToggle,
    playSoundToggle = playSoundToggle,
    showBadgeToggle = showBadgeToggle,
    resetButton = resetButton,
  }
end

ns.NotificationSettings = NotificationSettings
return NotificationSettings
