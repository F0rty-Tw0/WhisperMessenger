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
local LayoutThemeApply = ns.MessengerWindowLayoutThemeApply
  or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ThemeApply")
local ContactsSearchUI = ns.MessengerWindowLayoutContactsSearchUI
  or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContactsSearchUI")
local OptionsMenuButtons = ns.MessengerWindowLayoutOptionsMenuButtons
  or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.OptionsMenuButtons")
local OptionsPanelLayout = ns.MessengerWindowLayoutOptionsPanelLayout
  or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.OptionsPanelLayout")
local applyColorTexture = UIHelpers.applyColorTexture

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

  local contactsSearch = ContactsSearchUI.Build(factory, contactsPane, {
    contactsWidth = contactsWidth,
    searchMargin = searchMargin,
    searchHeight = searchHeight,
    searchClearButtonSize = searchClearButtonSize,
    dividerColor = dividerColor,
    theme = Theme,
    uiHelpers = UIHelpers,
    applyColorTexture = applyColorTexture,
  })
  local contactsSearchFrame = contactsSearch.frame
  local contactsSearchBg = contactsSearch.bg
  local searchBorderTop = contactsSearch.borderTop
  local searchBorderBottom = contactsSearch.borderBottom
  local searchBorderLeft = contactsSearch.borderLeft
  local searchBorderRight = contactsSearch.borderRight
  local contactsSearchInput = contactsSearch.input
  local contactsSearchPlaceholder = contactsSearch.placeholder
  local contactsSearchClearButton = contactsSearch.clearButton
  local contactsSearchClearLabel = contactsSearch.clearLabel

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

  local optionsPanelLayout = OptionsPanelLayout.Build(factory, frame, initialState, {
    contactsWidth = contactsWidth,
    theme = Theme,
    scrollView = ScrollView,
    applyColorTexture = applyColorTexture,
  })
  local optionsPanel = optionsPanelLayout.optionsPanel
  local optionsMenu = optionsPanelLayout.optionsMenu
  local optionsMenuBg = optionsPanelLayout.optionsMenuBg
  local menuPadding = optionsPanelLayout.menuPadding
  local optionsHeader = optionsPanelLayout.optionsHeader
  local optionsMenuDivider = optionsPanelLayout.optionsMenuDivider
  local optionsContentPane = optionsPanelLayout.optionsContentPane
  local optionsContentBg = optionsPanelLayout.optionsContentBg
  local optionsScrollView = optionsPanelLayout.optionsScrollView
  local OPTIONS_CONTENT_HEIGHT = optionsPanelLayout.optionsContentHeight

  local optionsMenuButtons = OptionsMenuButtons.Build(factory, optionsMenu, optionsHeader, {
    menuPadding = menuPadding,
    contactsWidth = contactsWidth,
    theme = Theme,
  })
  local generalTab = optionsMenuButtons.generalTab
  local appearanceTab = optionsMenuButtons.appearanceTab
  local behaviorTab = optionsMenuButtons.behaviorTab
  local notificationsTab = optionsMenuButtons.notificationsTab
  local resetWindowButton = optionsMenuButtons.resetWindowButton
  local resetIconButton = optionsMenuButtons.resetIconButton
  local clearAllChatsButton = optionsMenuButtons.clearAllChatsButton
  local optionsHint = optionsMenuButtons.optionsHint
  local layoutTheme = LayoutThemeApply.Create({
    theme = Theme,
    contactsPaneBg = contactsPaneBg,
    contactsSearchBg = contactsSearchBg,
    searchBorderTop = searchBorderTop,
    searchBorderBottom = searchBorderBottom,
    searchBorderLeft = searchBorderLeft,
    searchBorderRight = searchBorderRight,
    contactsSearchInput = contactsSearchInput,
    contactsSearchPlaceholder = contactsSearchPlaceholder,
    contactsSearchClearLabel = contactsSearchClearLabel,
    contactsDivider = contactsDivider,
    contactsPaneEdges = contactsPaneEdges,
    contactsHeaderDivider = contactsHeaderDivider,
    composerPaneBorder = composerPaneBorder,
    optionsMenuBg = optionsMenuBg,
    optionsMenuDivider = optionsMenuDivider,
    optionsContentBg = optionsContentBg,
    optionsHeader = optionsHeader,
    optionsHint = optionsHint,
    generalTab = generalTab,
    appearanceTab = appearanceTab,
    behaviorTab = behaviorTab,
    notificationsTab = notificationsTab,
    resetWindowButton = resetWindowButton,
    resetIconButton = resetIconButton,
    clearAllChatsButton = clearAllChatsButton,
  })
  local applyTheme = layoutTheme.applyTheme
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
