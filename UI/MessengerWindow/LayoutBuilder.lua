local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local LayoutMetrics = ns.MessengerWindowLayoutMetrics
  or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local LayoutApply = ns.MessengerWindowLayoutApply or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Apply")
local applyColorTexture = UIHelpers.applyColorTexture
local setTextColor = UIHelpers.setTextColor
local createOptionButton = UIHelpers.createOptionButton

local LayoutBuilder = {}

LayoutBuilder.ClampContactsWidth = LayoutMetrics.ClampContactsWidth

-- Creates all layout panes inside the window frame.
--
-- factory      : frame factory
-- frame        : the outer window frame (from ChromeBuilder)
-- initialState : { width, height, contactsWidth? }
-- options      : { contactsWidth? }
--
-- Returns:
--   contactsPane, contactsDivider, contactsResizeHandle, contentPane, headerDivider,
--   threadPane, composerPane, composerDivider, optionsPanel, optionsHeader, optionsHint,
--   resetWindowButton, resetIconButton, clearAllChatsButton, contactsView
function LayoutBuilder.Build(factory, frame, initialState, _options)
  _options = _options or {}
  local contactsWidth =
    LayoutBuilder.ClampContactsWidth(initialState.width, _options.contactsWidth or initialState.contactsWidth, Theme)
  local contactsHeight = initialState.height - Theme.TOP_BAR_HEIGHT
  local contentWidth = initialState.width - contactsWidth - Theme.DIVIDER_THICKNESS
  local contentHeight = initialState.height - Theme.TOP_BAR_HEIGHT
  local threadHeight = contentHeight - Theme.COMPOSER_HEIGHT - Theme.DIVIDER_THICKNESS
  local contactsHandleWidth = LayoutMetrics.GetContactsResizeHandleWidth(Theme)
  local searchHeight, searchMargin, searchClearButtonSize, searchTotalHeight =
    LayoutMetrics.ContactsSearchMetrics(Theme)
  local contactsListHeight = math.max(0, contactsHeight - searchTotalHeight)

  local dividerColor = Theme.COLORS.divider or { 0.15, 0.16, 0.22, 0.60 }
  local strongDividerColor = { dividerColor[1], dividerColor[2], dividerColor[3], 1 }
  local contactsSectionBorderColor = Theme.COLORS.contacts_border_right or Theme.COLORS.contacts_divider or dividerColor
  local strongContactsBorderColor = {
    contactsSectionBorderColor[1],
    contactsSectionBorderColor[2],
    contactsSectionBorderColor[3],
    contactsSectionBorderColor[4] or 1,
  }

  local contactsPane = factory.CreateFrame("Frame", nil, frame)
  contactsPane:SetSize(contactsWidth, contactsHeight)
  contactsPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Theme.TOP_BAR_HEIGHT)

  -- Contacts pane background and section border
  local contactsPaneBg = contactsPane:CreateTexture(nil, "BACKGROUND")
  contactsPaneBg:SetAllPoints(contactsPane)
  applyColorTexture(contactsPaneBg, Theme.COLORS.bg_secondary)
  local contactsPaneEdges = UIHelpers.createBorderBox(
    contactsPane,
    strongContactsBorderColor,
    Theme.DIVIDER_THICKNESS,
    "BORDER",
    { top = false, left = true, right = true, bottom = true }
  )
  local contactsHeaderDivider = contactsPane:CreateTexture(nil, "BORDER")
  contactsHeaderDivider:SetPoint("TOPLEFT", contactsPane, "TOPLEFT", 0, 0)
  contactsHeaderDivider:SetPoint("TOPRIGHT", contactsPane, "TOPRIGHT", 0, 0)
  contactsHeaderDivider:SetHeight(Theme.DIVIDER_THICKNESS)
  applyColorTexture(contactsHeaderDivider, dividerColor)
  local contactsPaneBorder = {
    top = contactsHeaderDivider,
    left = contactsPaneEdges and contactsPaneEdges.left or nil,
    right = contactsPaneEdges and contactsPaneEdges.right or nil,
    bottom = contactsPaneEdges and contactsPaneEdges.bottom or nil,
  }
  local contactsRightBorder = contactsPaneBorder.right

  local contactsSearchFrame = factory.CreateFrame("Frame", nil, contactsPane)
  contactsSearchFrame:SetSize(math.max(0, contactsWidth - (searchMargin * 2)), searchHeight)
  contactsSearchFrame:SetPoint("TOPLEFT", contactsPane, "TOPLEFT", searchMargin, -searchMargin)

  local contactsSearchBg = contactsSearchFrame:CreateTexture(nil, "BACKGROUND")
  contactsSearchBg:SetAllPoints(contactsSearchFrame)
  applyColorTexture(contactsSearchBg, Theme.COLORS.bg_search_input or Theme.COLORS.bg_input)

  local searchBorderColor = { dividerColor[1], dividerColor[2], dividerColor[3], 0.95 }
  local searchBorderTop = contactsSearchFrame:CreateTexture(nil, "BORDER")
  searchBorderTop:SetPoint("TOPLEFT", contactsSearchFrame, "TOPLEFT", 0, 0)
  searchBorderTop:SetPoint("TOPRIGHT", contactsSearchFrame, "TOPRIGHT", 0, 0)
  searchBorderTop:SetHeight(1)
  applyColorTexture(searchBorderTop, searchBorderColor)

  local searchBorderBottom = contactsSearchFrame:CreateTexture(nil, "BORDER")
  searchBorderBottom:SetPoint("BOTTOMLEFT", contactsSearchFrame, "BOTTOMLEFT", 0, 0)
  searchBorderBottom:SetPoint("BOTTOMRIGHT", contactsSearchFrame, "BOTTOMRIGHT", 0, 0)
  searchBorderBottom:SetHeight(1)
  applyColorTexture(searchBorderBottom, searchBorderColor)

  local searchBorderLeft = contactsSearchFrame:CreateTexture(nil, "BORDER")
  searchBorderLeft:SetPoint("TOPLEFT", contactsSearchFrame, "TOPLEFT", 0, 0)
  searchBorderLeft:SetPoint("BOTTOMLEFT", contactsSearchFrame, "BOTTOMLEFT", 0, 0)
  searchBorderLeft:SetWidth(1)
  applyColorTexture(searchBorderLeft, searchBorderColor)

  local searchBorderRight = contactsSearchFrame:CreateTexture(nil, "BORDER")
  searchBorderRight:SetPoint("TOPRIGHT", contactsSearchFrame, "TOPRIGHT", 0, 0)
  searchBorderRight:SetPoint("BOTTOMRIGHT", contactsSearchFrame, "BOTTOMRIGHT", 0, 0)
  searchBorderRight:SetWidth(1)
  applyColorTexture(searchBorderRight, searchBorderColor)

  local contactsSearchInput = factory.CreateFrame("EditBox", nil, contactsSearchFrame)
  contactsSearchInput:SetPoint("TOPLEFT", contactsSearchFrame, "TOPLEFT", 8, -4)
  contactsSearchInput:SetPoint("BOTTOMRIGHT", contactsSearchFrame, "BOTTOMRIGHT", -(searchClearButtonSize + 8), 4)
  contactsSearchInput:SetText("")
  UIHelpers.setFontObject(contactsSearchInput, Theme.FONTS.composer_input)
  if contactsSearchInput.SetTextInsets then
    contactsSearchInput:SetTextInsets(0, 0, 0, 0)
  end
  if contactsSearchInput.SetAutoFocus then
    contactsSearchInput:SetAutoFocus(false)
  end
  if contactsSearchInput.SetTextColor then
    contactsSearchInput:SetTextColor(
      Theme.COLORS.text_primary[1],
      Theme.COLORS.text_primary[2],
      Theme.COLORS.text_primary[3],
      Theme.COLORS.text_primary[4] or 1
    )
  end

  local contactsSearchPlaceholder = contactsSearchFrame:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_preview)
  contactsSearchPlaceholder:SetPoint("LEFT", contactsSearchInput, "LEFT", 0, 0)
  contactsSearchPlaceholder:SetText("Search chats")
  UIHelpers.setTextColor(contactsSearchPlaceholder, Theme.COLORS.text_secondary)

  local contactsSearchClearButton = factory.CreateFrame("Button", nil, contactsSearchFrame)
  contactsSearchClearButton:SetSize(searchClearButtonSize, searchClearButtonSize)
  contactsSearchClearButton:SetPoint("RIGHT", contactsSearchFrame, "RIGHT", -2, 0)
  contactsSearchClearButton:EnableMouse(true)

  local contactsSearchClearLabel = contactsSearchClearButton:CreateFontString(nil, "OVERLAY", Theme.FONTS.contact_name)
  contactsSearchClearLabel:SetPoint("CENTER", contactsSearchClearButton, "CENTER", 0, 0)
  contactsSearchClearLabel:SetText("X")
  UIHelpers.setTextColor(contactsSearchClearLabel, Theme.COLORS.text_secondary)

  contactsSearchPlaceholder:Show()
  contactsSearchClearButton:Hide()
  contactsSearchClearButton:SetScript("OnEnter", function()
    UIHelpers.setTextColor(contactsSearchClearLabel, Theme.COLORS.text_primary)
  end)
  contactsSearchClearButton:SetScript("OnLeave", function()
    UIHelpers.setTextColor(contactsSearchClearLabel, Theme.COLORS.text_secondary)
  end)

  local contactsView = ScrollView.Create(factory, contactsPane, {
    width = contactsWidth,
    height = contactsListHeight,
    point = { "TOPLEFT", contactsPane, "TOPLEFT", 0, -searchTotalHeight },
    step = Theme.LAYOUT.CONTACT_ROW_HEIGHT,
  })

  local contactsDivider = frame:CreateTexture(nil, "BORDER")
  contactsDivider:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", 0, 0)
  contactsDivider:SetSize(Theme.DIVIDER_THICKNESS, contactsHeight)
  applyColorTexture(contactsDivider, Theme.COLORS.contacts_divider or Theme.COLORS.divider)

  -- Drag handle over the contacts divider for contacts-only resizing.
  local contactsResizeHandle = factory.CreateFrame("Frame", nil, frame)
  contactsResizeHandle:SetSize(contactsHandleWidth, contactsHeight)
  contactsResizeHandle:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", -math.floor(contactsHandleWidth / 2), 0)
  contactsResizeHandle:EnableMouse(true)
  if contactsResizeHandle.SetFrameLevel and frame.GetFrameLevel then
    contactsResizeHandle:SetFrameLevel(frame:GetFrameLevel() + 15)
  end
  local contactsResizeHandleBg = contactsResizeHandle:CreateTexture(nil, "BACKGROUND")
  contactsResizeHandleBg:SetAllPoints(contactsResizeHandle)
  applyColorTexture(contactsResizeHandleBg, { 0, 0, 0, 0 })
  contactsResizeHandle.hoverBg = contactsResizeHandleBg

  local resizeOutlineThickness = 2
  local contactsResizeOutline = {}
  contactsResizeOutline.top = contactsResizeHandle:CreateTexture(nil, "OVERLAY")
  contactsResizeOutline.top:SetPoint("TOPLEFT", contactsResizeHandle, "TOPLEFT", 0, 0)
  contactsResizeOutline.top:SetPoint("TOPRIGHT", contactsResizeHandle, "TOPRIGHT", 0, 0)
  contactsResizeOutline.top:SetHeight(resizeOutlineThickness)
  contactsResizeOutline.bottom = contactsResizeHandle:CreateTexture(nil, "OVERLAY")
  contactsResizeOutline.bottom:SetPoint("BOTTOMLEFT", contactsResizeHandle, "BOTTOMLEFT", 0, 0)
  contactsResizeOutline.bottom:SetPoint("BOTTOMRIGHT", contactsResizeHandle, "BOTTOMRIGHT", 0, 0)
  contactsResizeOutline.bottom:SetHeight(resizeOutlineThickness)
  contactsResizeOutline.left = contactsResizeHandle:CreateTexture(nil, "OVERLAY")
  contactsResizeOutline.left:SetPoint("TOPLEFT", contactsResizeHandle, "TOPLEFT", 0, 0)
  contactsResizeOutline.left:SetPoint("BOTTOMLEFT", contactsResizeHandle, "BOTTOMLEFT", 0, 0)
  contactsResizeOutline.left:SetWidth(resizeOutlineThickness)
  contactsResizeOutline.right = contactsResizeHandle:CreateTexture(nil, "OVERLAY")
  contactsResizeOutline.right:SetPoint("TOPRIGHT", contactsResizeHandle, "TOPRIGHT", 0, 0)
  contactsResizeOutline.right:SetPoint("BOTTOMRIGHT", contactsResizeHandle, "BOTTOMRIGHT", 0, 0)
  contactsResizeOutline.right:SetWidth(resizeOutlineThickness)

  for _, edge in pairs(contactsResizeOutline) do
    applyColorTexture(edge, { 0, 0, 0, 0 })
    edge:Hide()
  end
  contactsResizeHandle.outline = contactsResizeOutline

  local contentPane = factory.CreateFrame("Frame", nil, frame)
  contentPane:SetSize(contentWidth, contentHeight)
  contentPane:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", Theme.DIVIDER_THICKNESS, 0)

  local threadPane = factory.CreateFrame("Frame", nil, contentPane)
  threadPane:SetSize(contentWidth, threadHeight)
  threadPane:SetPoint("TOPLEFT", contentPane, "TOPLEFT", 0, 0)
  local headerDivider = nil

  local composerPane = factory.CreateFrame("Frame", nil, contentPane)
  composerPane:SetSize(contentWidth, Theme.COMPOSER_HEIGHT)
  composerPane:SetPoint("BOTTOMLEFT", contentPane, "BOTTOMLEFT", 0, 0)
  local composerPaneBorder =
    UIHelpers.createBorderBox(composerPane, strongDividerColor, Theme.DIVIDER_THICKNESS, "BORDER")
  local composerDivider = composerPaneBorder and composerPaneBorder.top or nil

  -- Options overlay container (hides contacts + content when visible)
  local optionsPanel = factory.CreateFrame("Frame", nil, frame)
  optionsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Theme.TOP_BAR_HEIGHT)
  optionsPanel:SetSize(initialState.width, initialState.height - Theme.TOP_BAR_HEIGHT)

  -- Left sidebar menu
  local optionsMenu = factory.CreateFrame("Frame", nil, optionsPanel)
  optionsMenu:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 0, 0)
  optionsMenu:SetSize(contactsWidth, initialState.height - Theme.TOP_BAR_HEIGHT)

  local optionsMenuBg = optionsMenu:CreateTexture(nil, "BACKGROUND")
  optionsMenuBg:SetAllPoints(optionsMenu)
  applyColorTexture(optionsMenuBg, Theme.COLORS.bg_secondary)

  local menuPadding = Theme.CONTENT_PADDING

  local optionsHeader = optionsMenu:CreateFontString(nil, "OVERLAY", Theme.FONTS.header_name)
  optionsHeader:SetPoint("TOPLEFT", optionsMenu, "TOPLEFT", menuPadding, -menuPadding)
  optionsHeader:SetText("Options")

  -- Divider between menu and content
  local optionsMenuDivider = optionsPanel:CreateTexture(nil, "BORDER")
  optionsMenuDivider:SetPoint("TOPLEFT", optionsMenu, "TOPRIGHT", 0, 0)
  optionsMenuDivider:SetSize(Theme.DIVIDER_THICKNESS, initialState.height - Theme.TOP_BAR_HEIGHT)
  applyColorTexture(optionsMenuDivider, Theme.COLORS.divider)

  -- Right content pane for settings views (scrollable)
  local optionsContentWidth = initialState.width - contactsWidth - Theme.DIVIDER_THICKNESS
  local optionsContentH = initialState.height - Theme.TOP_BAR_HEIGHT
  local optionsContentPane = factory.CreateFrame("Frame", nil, optionsPanel)
  optionsContentPane:SetPoint("TOPLEFT", optionsMenu, "TOPRIGHT", Theme.DIVIDER_THICKNESS, 0)
  optionsContentPane:SetSize(optionsContentWidth, optionsContentH)

  local optionsContentBg = optionsContentPane:CreateTexture(nil, "BACKGROUND")
  optionsContentBg:SetAllPoints(optionsContentPane)
  applyColorTexture(optionsContentBg, Theme.COLORS.bg_primary)

  local OPTIONS_CONTENT_HEIGHT = 420
  local optionsScrollView = ScrollView.Create(factory, optionsContentPane, {
    width = optionsContentWidth,
    height = optionsContentH,
    step = 24,
  })
  optionsScrollView.content:SetSize(optionsContentWidth, OPTIONS_CONTENT_HEIGHT)

  -- Category tabs at top of menu (below header)
  local tabColors = {
    bg = Theme.COLORS.option_button_bg,
    bgHover = Theme.COLORS.option_button_hover,
    text = Theme.COLORS.option_button_text,
    textHover = Theme.COLORS.option_button_text_hover,
  }
  local tabLayout = { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = contactsWidth - (menuPadding * 2) }
  local tabSpacing = 4

  local generalTab = createOptionButton(factory, optionsMenu, "General", tabColors, tabLayout)
  generalTab:SetPoint("TOPLEFT", optionsHeader, "BOTTOMLEFT", 0, -menuPadding)

  local appearanceTab = createOptionButton(factory, optionsMenu, "Appearance", tabColors, tabLayout)
  appearanceTab:SetPoint("TOPLEFT", generalTab, "BOTTOMLEFT", 0, -tabSpacing)

  local behaviorTab = createOptionButton(factory, optionsMenu, "Behavior", tabColors, tabLayout)
  behaviorTab:SetPoint("TOPLEFT", appearanceTab, "BOTTOMLEFT", 0, -tabSpacing)

  local notificationsTab = createOptionButton(factory, optionsMenu, "Notifications", tabColors, tabLayout)
  notificationsTab:SetPoint("TOPLEFT", behaviorTab, "BOTTOMLEFT", 0, -tabSpacing)

  -- Action buttons anchored to bottom of menu
  local btnH = Theme.LAYOUT.OPTION_BUTTON_HEIGHT
  local btnSpacing = Theme.LAYOUT.OPTION_BUTTON_SPACING
  local normalColors = {
    bg = Theme.COLORS.option_button_bg,
    bgHover = Theme.COLORS.option_button_hover,
    text = Theme.COLORS.option_button_text,
    textHover = Theme.COLORS.option_button_text_hover,
  }
  local dangerColors = {
    bg = Theme.COLORS.danger_button_bg,
    bgHover = Theme.COLORS.danger_button_hover,
    text = Theme.COLORS.option_button_text,
    textHover = Theme.COLORS.option_button_text_hover,
  }
  local btnLayout = { height = btnH, width = contactsWidth - (menuPadding * 2) }

  local clearAllChatsButton = createOptionButton(factory, optionsMenu, "Clear All Chats", dangerColors, btnLayout)
  clearAllChatsButton:SetPoint("BOTTOMLEFT", optionsMenu, "BOTTOMLEFT", menuPadding, menuPadding)

  local resetIconButton = createOptionButton(factory, optionsMenu, "Reset Icon Position", normalColors, btnLayout)
  resetIconButton:SetPoint("BOTTOMLEFT", clearAllChatsButton, "TOPLEFT", 0, btnSpacing)

  local resetWindowButton = createOptionButton(factory, optionsMenu, "Reset Window Position", normalColors, btnLayout)
  resetWindowButton:SetPoint("BOTTOMLEFT", resetIconButton, "TOPLEFT", 0, btnSpacing)

  local optionsHint = optionsMenu:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
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
    activeTheme = activeTheme or Theme

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
  applyTheme(Theme)

  return {
    contactsPane = contactsPane,
    contactsPaneBorder = contactsPaneBorder,
    contactsDivider = contactsDivider,
    contactsRightBorder = contactsRightBorder,
    contactsResizeHandle = contactsResizeHandle,
    contactsWidth = contactsWidth,
    contactsHandleWidth = contactsHandleWidth,
    contactsSearchFrame = contactsSearchFrame,
    contactsSearchBg = contactsSearchBg,
    contactsSearchInput = contactsSearchInput,
    contactsSearchPlaceholder = contactsSearchPlaceholder,
    contactsSearchClearButton = contactsSearchClearButton,
    contactsSearchHeight = searchHeight,
    contactsSearchMargin = searchMargin,
    contactsSearchTotalHeight = searchTotalHeight,
    contactsListHeight = contactsListHeight,
    contactsView = contactsView,
    optionsContentHeight = OPTIONS_CONTENT_HEIGHT,
    contentPane = contentPane,
    contactsHeaderDivider = contactsHeaderDivider,
    headerDivider = headerDivider,
    threadPane = threadPane,
    composerPane = composerPane,
    composerPaneBorder = composerPaneBorder,
    composerDivider = composerDivider,
    optionsPanel = optionsPanel,
    optionsMenu = optionsMenu,
    optionsMenuDivider = optionsMenuDivider,
    optionsContentPane = optionsContentPane,
    optionsScrollView = optionsScrollView,
    generalTab = generalTab,
    appearanceTab = appearanceTab,
    behaviorTab = behaviorTab,
    notificationsTab = notificationsTab,
    optionsHeader = optionsHeader,
    optionsHint = optionsHint,
    resetWindowButton = resetWindowButton,
    resetIconButton = resetIconButton,
    clearAllChatsButton = clearAllChatsButton,
    applyTheme = applyTheme,
  }
end

-- Recalculate all pane sizes after a frame resize.
-- layout: the table returned by LayoutBuilder.Build
-- width, height: new frame dimensions
-- requestedContactsWidth: optional target contacts pane width
-- Returns: { contactsWidth, contentWidth, contactsHeight, threadHeight }
function LayoutBuilder.Relayout(layout, width, height, requestedContactsWidth)
  local relayout = LayoutMetrics.CalculateRelayout(layout, width, height, requestedContactsWidth, Theme)
  return LayoutApply.Relayout(layout, relayout, Theme)
end

ns.MessengerWindowLayoutBuilder = LayoutBuilder

return LayoutBuilder
