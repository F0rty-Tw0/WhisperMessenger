local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local NativeControls = ns.UIHelpersNativeControls or require("WhisperMessenger.UI.Helpers.NativeControls")
local Localization = ns.Localization or require("WhisperMessenger.Locale.Localization")
local createOptionButton = UIHelpers.createOptionButton

local OptionsMenuButtons = {}

-- Settings pages in nav order; SettingsPanels defines the pages in the same
-- order, so tab N opens page N.
local SETTINGS_TABS = {
  { name = "generalTab", label = "General", icon = "nav_general_icon" },
  { name = "appearanceTab", label = "Appearance", icon = "nav_appearance_icon" },
  { name = "behaviorTab", label = "Behavior", icon = "nav_behavior_icon" },
  { name = "whispersTab", label = "Whispers", icon = "nav_whispers_icon" },
  { name = "chatsTab", label = "Chats", icon = "nav_chats_icon" },
  { name = "filtersTab", label = "Filters", icon = "nav_filters_icon" },
  { name = "notificationsTab", label = "Notifications", icon = "nav_notifications_icon" },
  { name = "iconsTab", label = "Icons", icon = "nav_icons_icon" },
  { name = "whatsNewTab", label = "What's New", icon = "title_whats_new_icon" },
}

local function optionButtonWidth(contactsWidth, menuPadding)
  return contactsWidth - (menuPadding * 2)
end

function OptionsMenuButtons.Build(factory, optionsMenu, options)
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

  -- One nav tab per settings page, top to bottom in page order.
  local settingsTabs = {}
  local tabsByName = {}
  for index, tabSpec in ipairs(SETTINGS_TABS) do
    tabLayout.icon = theme.TEXTURES and theme.TEXTURES[tabSpec.icon] or nil
    local tab = optionButtonFactory(factory, optionsMenu, Localization.Text(tabSpec.label), tabColors, tabLayout)
    if index == 1 then
      tab:SetPoint("TOPLEFT", optionsMenu, "TOPLEFT", menuPadding, -menuPadding)
    else
      tab:SetPoint("TOPLEFT", settingsTabs[index - 1], "BOTTOMLEFT", 0, -tabSpacing)
    end
    settingsTabs[index] = tab
    tabsByName[tabSpec.name] = tab
  end

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
    local button = UIHelpers.createTemplatedFrame(factory, "Button", nil, optionsMenu, NativeControls.BUTTON_TEMPLATE)
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
    for index, tabSpec in ipairs(SETTINGS_TABS) do
      setButtonText(settingsTabs[index], tabSpec.label)
    end
    setButtonText(clearAllChatsButton, "Clear All Chats")
    setButtonText(resetIconButton, "Reset Icon")
    setButtonText(resetWindowButton, "Reset Window")
    optionsHint:SetText(Localization.Text("Reset positions or clear all conversation history."))
  end

  -- Height the tab list plus the footer need; a shorter menu scrolls
  -- instead of drawing the hint over the last tabs.
  local function contentHeight()
    local tabCount = #settingsTabs
    local tabsHeight = menuPadding + tabCount * tabLayout.height + (tabCount - 1) * tabSpacing
    local hintHeight = optionsHint.GetStringHeight and optionsHint:GetStringHeight() or 0
    local footerHeight = hintHeight + menuPadding + 3 * btnH + 2 * btnSpacing + menuPadding
    return tabsHeight + menuPadding + footerHeight
  end

  local result = {
    contentHeight = contentHeight,
    settingsTabs = settingsTabs,
    resetWindowButton = resetWindowButton,
    resetIconButton = resetIconButton,
    clearAllChatsButton = clearAllChatsButton,
    optionsHint = optionsHint,
    setLanguage = setLanguage,
  }
  for name, tab in pairs(tabsByName) do
    result[name] = tab
  end
  return result
end

ns.MessengerWindowLayoutOptionsMenuButtons = OptionsMenuButtons

return OptionsMenuButtons
