local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local createOptionButton = UIHelpers.createOptionButton

local OptionsMenuButtons = {}

local function optionButtonWidth(contactsWidth, menuPadding)
  return contactsWidth - (menuPadding * 2)
end

function OptionsMenuButtons.Build(factory, optionsMenu, optionsHeader, options)
  options = options or {}

  local theme = options.theme or Theme
  local menuPadding = options.menuPadding
  local contactsWidth = options.contactsWidth
  local optionButtonFactory = options.createOptionButton or createOptionButton

  local tabColors = {
    bg = theme.COLORS.option_button_bg,
    bgHover = theme.COLORS.option_button_hover,
    text = theme.COLORS.option_button_text,
    textHover = theme.COLORS.option_button_text_hover,
  }
  local tabLayout = { height = theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = optionButtonWidth(contactsWidth, menuPadding) }
  local tabSpacing = 4

  local generalTab = optionButtonFactory(factory, optionsMenu, "General", tabColors, tabLayout)
  generalTab:SetPoint("TOPLEFT", optionsHeader, "BOTTOMLEFT", 0, -menuPadding)

  local appearanceTab = optionButtonFactory(factory, optionsMenu, "Appearance", tabColors, tabLayout)
  appearanceTab:SetPoint("TOPLEFT", generalTab, "BOTTOMLEFT", 0, -tabSpacing)

  local behaviorTab = optionButtonFactory(factory, optionsMenu, "Behavior", tabColors, tabLayout)
  behaviorTab:SetPoint("TOPLEFT", appearanceTab, "BOTTOMLEFT", 0, -tabSpacing)

  local notificationsTab = optionButtonFactory(factory, optionsMenu, "Notifications", tabColors, tabLayout)
  notificationsTab:SetPoint("TOPLEFT", behaviorTab, "BOTTOMLEFT", 0, -tabSpacing)

  local btnH = theme.LAYOUT.OPTION_BUTTON_HEIGHT
  local btnSpacing = theme.LAYOUT.OPTION_BUTTON_SPACING
  local normalColors = {
    bg = theme.COLORS.option_button_bg,
    bgHover = theme.COLORS.option_button_hover,
    text = theme.COLORS.option_button_text,
    textHover = theme.COLORS.option_button_text_hover,
  }
  local dangerColors = {
    bg = theme.COLORS.danger_button_bg,
    bgHover = theme.COLORS.danger_button_hover,
    text = theme.COLORS.option_button_text,
    textHover = theme.COLORS.option_button_text_hover,
  }
  local btnLayout = { height = btnH, width = optionButtonWidth(contactsWidth, menuPadding) }

  local clearAllChatsButton = optionButtonFactory(factory, optionsMenu, "Clear All Chats", dangerColors, btnLayout)
  clearAllChatsButton:SetPoint("BOTTOMLEFT", optionsMenu, "BOTTOMLEFT", menuPadding, menuPadding)

  local resetIconButton = optionButtonFactory(factory, optionsMenu, "Reset Icon Position", normalColors, btnLayout)
  resetIconButton:SetPoint("BOTTOMLEFT", clearAllChatsButton, "TOPLEFT", 0, btnSpacing)

  local resetWindowButton = optionButtonFactory(factory, optionsMenu, "Reset Window Position", normalColors, btnLayout)
  resetWindowButton:SetPoint("BOTTOMLEFT", resetIconButton, "TOPLEFT", 0, btnSpacing)

  local optionsHint = optionsMenu:CreateFontString(nil, "OVERLAY", theme.FONTS.system_text)
  optionsHint:SetPoint("BOTTOMLEFT", resetWindowButton, "TOPLEFT", 0, menuPadding)
  optionsHint:SetText("Reset positions or clear all conversation history.")

  if optionsHint.SetJustifyH then
    optionsHint:SetJustifyH("LEFT")
  end
  if optionsHint.SetWordWrap then
    optionsHint:SetWordWrap(true)
  end
  if optionsHint.SetWidth then
    optionsHint:SetWidth(btnLayout.width)
  end

  return {
    generalTab = generalTab,
    appearanceTab = appearanceTab,
    behaviorTab = behaviorTab,
    notificationsTab = notificationsTab,
    resetWindowButton = resetWindowButton,
    resetIconButton = resetIconButton,
    clearAllChatsButton = clearAllChatsButton,
    optionsHint = optionsHint,
  }
end

ns.MessengerWindowLayoutOptionsMenuButtons = OptionsMenuButtons

return OptionsMenuButtons
