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
  -- Tabs render as a list (see NavItem).
  local tabLayout = { height = theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = optionButtonWidth(contactsWidth, menuPadding), nav = true }
  local tabSpacing = 4

  local generalTab = optionButtonFactory(factory, optionsMenu, Localization.Text("General"), tabColors, tabLayout)
  generalTab:SetPoint("TOPLEFT", optionsHeader, "BOTTOMLEFT", 0, -menuPadding)

  local appearanceTab = optionButtonFactory(factory, optionsMenu, Localization.Text("Appearance"), tabColors, tabLayout)
  appearanceTab:SetPoint("TOPLEFT", generalTab, "BOTTOMLEFT", 0, -tabSpacing)

  local behaviorTab = optionButtonFactory(factory, optionsMenu, Localization.Text("Behavior"), tabColors, tabLayout)
  behaviorTab:SetPoint("TOPLEFT", appearanceTab, "BOTTOMLEFT", 0, -tabSpacing)

  local notificationsTab = optionButtonFactory(factory, optionsMenu, Localization.Text("Notifications"), tabColors, tabLayout)
  notificationsTab:SetPoint("TOPLEFT", behaviorTab, "BOTTOMLEFT", 0, -tabSpacing)
  local iconsTab = optionButtonFactory(factory, optionsMenu, Localization.Text("Icons"), tabColors, tabLayout)
  iconsTab:SetPoint("TOPLEFT", notificationsTab, "BOTTOMLEFT", 0, -tabSpacing)

  local whatsNewTab = optionButtonFactory(factory, optionsMenu, Localization.Text("What's New"), tabColors, tabLayout)
  whatsNewTab:SetPoint("TOPLEFT", iconsTab, "BOTTOMLEFT", 0, -tabSpacing)

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
  -- Utility actions are ghost buttons; Clear All Chats is the red danger
  -- ghost.
  local btnLayout = { height = btnH, width = optionButtonWidth(contactsWidth, menuPadding), ghost = true }
  local dangerLayout = { height = btnH, width = btnLayout.width, ghost = true, danger = true }

  -- Native WoW HUD: Blizzard red-gold UIPanelButtonTemplate. Returns nil in
  -- modern mode or when the template is unavailable (modern ghost button).
  local nativeChrome = options.nativeChrome == true
  local function nativeButton(key)
    if not nativeChrome then
      return nil
    end
    local button = UIHelpers.createTemplatedFrame(factory, "Button", nil, optionsMenu, "UIPanelButtonTemplate")
    if button then
      button:SetSize(btnLayout.width, btnH)
      button:SetText(Localization.Text(key))
    end
    return button
  end

  local clearAllChatsButton = nativeButton("Clear All Chats")
    or optionButtonFactory(factory, optionsMenu, Localization.Text("Clear All Chats"), dangerColors, dangerLayout)
  clearAllChatsButton:SetPoint("BOTTOMLEFT", optionsMenu, "BOTTOMLEFT", menuPadding, menuPadding)

  local resetIconButton = nativeButton("Reset Icon")
    or optionButtonFactory(factory, optionsMenu, Localization.Text("Reset Icon"), normalColors, btnLayout)
  resetIconButton:SetPoint("BOTTOMLEFT", clearAllChatsButton, "TOPLEFT", 0, btnSpacing)

  local resetWindowButton = nativeButton("Reset Window")
    or optionButtonFactory(factory, optionsMenu, Localization.Text("Reset Window"), normalColors, btnLayout)
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
    elseif button and button.SetText then
      -- Blizzard template button: label lives on the button itself.
      button:SetText(Localization.Text(key))
    end
  end

  local function setLanguage()
    setButtonText(generalTab, "General")
    setButtonText(appearanceTab, "Appearance")
    setButtonText(behaviorTab, "Behavior")
    setButtonText(notificationsTab, "Notifications")
    setButtonText(iconsTab, "Icons")
    setButtonText(whatsNewTab, "What's New")
    setButtonText(clearAllChatsButton, "Clear All Chats")
    setButtonText(resetIconButton, "Reset Icon")
    setButtonText(resetWindowButton, "Reset Window")
    optionsHint:SetText(Localization.Text("Reset positions or clear all conversation history."))
  end

  return {
    generalTab = generalTab,
    appearanceTab = appearanceTab,
    behaviorTab = behaviorTab,
    notificationsTab = notificationsTab,
    iconsTab = iconsTab,
    whatsNewTab = whatsNewTab,
    resetWindowButton = resetWindowButton,
    resetIconButton = resetIconButton,
    clearAllChatsButton = clearAllChatsButton,
    optionsHint = optionsHint,
    setLanguage = setLanguage,
  }
end

ns.MessengerWindowLayoutOptionsMenuButtons = OptionsMenuButtons

return OptionsMenuButtons
