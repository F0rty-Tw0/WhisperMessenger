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
  local contactsSearchBg = options.contactsSearchBg
  local searchBorderTop = options.searchBorderTop
  local searchBorderBottom = options.searchBorderBottom
  local searchBorderLeft = options.searchBorderLeft
  local searchBorderRight = options.searchBorderRight
  local contactsSearchInput = options.contactsSearchInput
  local contactsSearchPlaceholder = options.contactsSearchPlaceholder
  local contactsSearchClearLabel = options.contactsSearchClearLabel
  local contactsDivider = options.contactsDivider
  local contactsPaneEdges = options.contactsPaneEdges
  local contactsHeaderDivider = options.contactsHeaderDivider
  local composerPaneBorder = options.composerPaneBorder
  local optionsMenuBg = options.optionsMenuBg
  local optionsMenuDivider = options.optionsMenuDivider
  local optionsContentBg = options.optionsContentBg
  local optionsHeader = options.optionsHeader
  local optionsHint = options.optionsHint
  local generalTab = options.generalTab
  local appearanceTab = options.appearanceTab
  local behaviorTab = options.behaviorTab
  local notificationsTab = options.notificationsTab
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

    applyColorTexture(contactsPaneBg, activeTheme.COLORS.bg_secondary)
    applyColorTexture(contactsSearchBg, activeTheme.COLORS.bg_search_input or activeTheme.COLORS.bg_input)

    local divider = activeTheme.COLORS.divider or { 0.15, 0.16, 0.22, 0.60 }
    local searchBorder = { divider[1], divider[2], divider[3], 0.95 }
    applyColorTexture(searchBorderTop, searchBorder)
    applyColorTexture(searchBorderBottom, searchBorder)
    applyColorTexture(searchBorderLeft, searchBorder)
    applyColorTexture(searchBorderRight, searchBorder)
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
    applyColorTexture(contactsDivider, activeTheme.COLORS.contacts_divider or activeTheme.COLORS.divider)

    local strongDividerThemeColor = { divider[1], divider[2], divider[3], 1 }
    local activeContactsBorder = activeTheme.COLORS.contacts_border_right
      or activeTheme.COLORS.contacts_divider
      or divider
    local strongActiveContactsBorder = {
      activeContactsBorder[1],
      activeContactsBorder[2],
      activeContactsBorder[3],
      activeContactsBorder[4] or 1,
    }

    UIHelpers.applyBorderBoxColor(contactsPaneEdges, strongActiveContactsBorder)
    applyColorTexture(contactsHeaderDivider, divider)
    UIHelpers.applyBorderBoxColor(composerPaneBorder, strongDividerThemeColor)

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

    for _, tab in ipairs({ generalTab, appearanceTab, behaviorTab, notificationsTab }) do
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
