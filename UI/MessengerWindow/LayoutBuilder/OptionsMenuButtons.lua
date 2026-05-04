local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
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

  local generalTab = optionButtonFactory(factory, optionsMenu, Localization.Text("General"), tabColors, tabLayout)
  generalTab:SetPoint("TOPLEFT", optionsHeader, "BOTTOMLEFT", 0, -menuPadding)

  local appearanceTab = optionButtonFactory(factory, optionsMenu, Localization.Text("Appearance"), tabColors, tabLayout)
  appearanceTab:SetPoint("TOPLEFT", generalTab, "BOTTOMLEFT", 0, -tabSpacing)

  local behaviorTab = optionButtonFactory(factory, optionsMenu, Localization.Text("Behavior"), tabColors, tabLayout)
  behaviorTab:SetPoint("TOPLEFT", appearanceTab, "BOTTOMLEFT", 0, -tabSpacing)

  local notificationsTab = optionButtonFactory(factory, optionsMenu, Localization.Text("Notifications"), tabColors, tabLayout)
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

  local clearAllChatsButton = optionButtonFactory(factory, optionsMenu, Localization.Text("Clear All Chats"), dangerColors, btnLayout)
  clearAllChatsButton:SetPoint("BOTTOMLEFT", optionsMenu, "BOTTOMLEFT", menuPadding, menuPadding)

  local resetIconButton = optionButtonFactory(factory, optionsMenu, Localization.Text("Reset Icon Position"), normalColors, btnLayout)
  resetIconButton:SetPoint("BOTTOMLEFT", clearAllChatsButton, "TOPLEFT", 0, btnSpacing)

  local resetWindowButton = optionButtonFactory(factory, optionsMenu, Localization.Text("Reset Window Position"), normalColors, btnLayout)
  resetWindowButton:SetPoint("BOTTOMLEFT", resetIconButton, "TOPLEFT", 0, btnSpacing)

  local optionsHint = optionsMenu:CreateFontString(nil, "OVERLAY", theme.FONTS.system_text)
  optionsHint:SetPoint("BOTTOMLEFT", resetWindowButton, "TOPLEFT", 0, menuPadding)
  optionsHint:SetText(Localization.Text("Reset positions or clear all conversation history."))

  if optionsHint.SetJustifyH then
    optionsHint:SetJustifyH("LEFT")
  end
  if optionsHint.SetWordWrap then
    optionsHint:SetWordWrap(true)
  end
  if optionsHint.SetWidth then
    optionsHint:SetWidth(btnLayout.width)
  end

  local function setButtonText(button, key)
    local label = button and button.label
    if label and label.SetText then
      label:SetText(Localization.Text(key))
    end
  end

  local function setLanguage()
    setButtonText(generalTab, "General")
    setButtonText(appearanceTab, "Appearance")
    setButtonText(behaviorTab, "Behavior")
    setButtonText(notificationsTab, "Notifications")
    setButtonText(clearAllChatsButton, "Clear All Chats")
    setButtonText(resetIconButton, "Reset Icon Position")
    setButtonText(resetWindowButton, "Reset Window Position")
    optionsHint:SetText(Localization.Text("Reset positions or clear all conversation history."))
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
    setLanguage = setLanguage,
  }
end

ns.MessengerWindowLayoutOptionsMenuButtons = OptionsMenuButtons

return OptionsMenuButtons
