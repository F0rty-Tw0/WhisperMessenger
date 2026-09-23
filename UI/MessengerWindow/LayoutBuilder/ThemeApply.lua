local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture
local setTextColor = UIHelpers.setTextColor

local ThemeApply = {}

function ThemeApply.Create(options)
  options = options or {}

  local fallbackTheme = options.theme or Theme
  local contactsPaneBg = options.contactsPaneBg
  local nativeChrome = options.nativeChrome == true
  local nativeSearch = options.nativeSearch == true
  local contactsSearchInput = options.contactsSearchInput
  local applySearchSkin = options.applySearchSkin
  local contactsSearchPlaceholder = options.contactsSearchPlaceholder
  local contactsSearchClearLabel = options.contactsSearchClearLabel
  local contactsDivider = options.contactsDivider
  local optionsMenuBg = options.optionsMenuBg
  local optionsMenuDivider = options.optionsMenuDivider
  local optionsContentBg = options.optionsContentBg
  local optionsHeader = options.optionsHeader
  local optionsHint = options.optionsHint
  local generalTab = options.generalTab
  local appearanceTab = options.appearanceTab
  local behaviorTab = options.behaviorTab
  local notificationsTab = options.notificationsTab
  local iconsTab = options.iconsTab
  local whatsNewTab = options.whatsNewTab
  local resetWindowButton = options.resetWindowButton
  local resetIconButton = options.resetIconButton
  local clearAllChatsButton = options.clearAllChatsButton

  local function paintOptionButton(button, backgroundColor, textColor, hoverBackgroundColor, hoverTextColor)
    if not button then
      return
    end

    if button.applyThemeColors then
      button.applyThemeColors({
        bg = backgroundColor,
        bgHover = hoverBackgroundColor or backgroundColor,
        text = textColor,
        textHover = hoverTextColor or textColor,
      })
      return
    end

    if button.bg then
      applyColorTexture(button.bg, backgroundColor)
    end
    if button.label then
      setTextColor(button.label, textColor)
    end
  end

  local function applyTheme(activeTheme)
    activeTheme = activeTheme or fallbackTheme

    -- Native WoW HUD keeps the pane clear so the template texture shows through.
    applyColorTexture(contactsPaneBg, nativeChrome and UIHelpers.TRANSPARENT or activeTheme.COLORS.bg_secondary)
    -- Native WoW HUD search box keeps Blizzard's own text colours.
    if not nativeSearch then
      if contactsSearchInput.SetTextColor then
        contactsSearchInput:SetTextColor(
          activeTheme.COLORS.text_primary[1],
          activeTheme.COLORS.text_primary[2],
          activeTheme.COLORS.text_primary[3],
          activeTheme.COLORS.text_primary[4] or 1
        )
      end

      setTextColor(contactsSearchPlaceholder, activeTheme.COLORS.text_secondary)
      setTextColor(contactsSearchClearLabel, activeTheme.COLORS.text_secondary)
    end
    applyColorTexture(contactsDivider, activeTheme.COLORS.contacts_divider or activeTheme.COLORS.divider)

    if applySearchSkin then
      applySearchSkin(activeTheme)
    end

    applyColorTexture(optionsMenuBg, activeTheme.COLORS.bg_secondary)
    applyColorTexture(optionsMenuDivider, activeTheme.COLORS.divider)
    applyColorTexture(optionsContentBg, activeTheme.COLORS.bg_primary)
    setTextColor(optionsHeader, activeTheme.COLORS.text_primary)
    setTextColor(optionsHint, activeTheme.COLORS.text_secondary)

    local activeTabBg = activeTheme.COLORS.option_button_active or activeTheme.COLORS.bg_contact_selected
    local activeTabHoverBg = activeTheme.COLORS.option_button_active_hover or activeTabBg
    local activeTabText = activeTheme.COLORS.option_button_text_active or activeTheme.COLORS.text_primary
    local inactiveTabBg = activeTheme.COLORS.option_button_bg
    local inactiveTabHoverBg = activeTheme.COLORS.option_button_hover
    local inactiveTabText = activeTheme.COLORS.option_button_text
    local inactiveTabHoverText = activeTheme.COLORS.option_button_text_hover

    for _, tab in ipairs({ generalTab, appearanceTab, behaviorTab, notificationsTab, iconsTab, whatsNewTab }) do
      if tab and tab._wmIsActiveTab then
        paintOptionButton(tab, activeTabBg, activeTabText, activeTabHoverBg, activeTabText)
      else
        paintOptionButton(tab, inactiveTabBg, inactiveTabText, inactiveTabHoverBg, inactiveTabHoverText)
      end
    end

    paintOptionButton(
      resetWindowButton,
      activeTheme.COLORS.option_button_bg,
      activeTheme.COLORS.option_button_text,
      activeTheme.COLORS.option_button_hover,
      activeTheme.COLORS.option_button_text_hover
    )
    paintOptionButton(
      resetIconButton,
      activeTheme.COLORS.option_button_bg,
      activeTheme.COLORS.option_button_text,
      activeTheme.COLORS.option_button_hover,
      activeTheme.COLORS.option_button_text_hover
    )
    paintOptionButton(
      clearAllChatsButton,
      activeTheme.COLORS.danger_button_bg,
      activeTheme.COLORS.option_button_text,
      activeTheme.COLORS.danger_button_hover,
      activeTheme.COLORS.option_button_text_hover
    )
  end

  return {
    applyTheme = applyTheme,
  }
end

ns.MessengerWindowLayoutThemeApply = ThemeApply

return ThemeApply
