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
  local sizing = LayoutMetrics.CalculateRelayout(
    {},
    initialState.width,
    initialState.height,
    _options.contactsWidth or initialState.contactsWidth,
    Theme
  )
  local contactsWidth = sizing.contactsWidth
  local contactsHeight = sizing.contactsHeight
  local contentWidth = sizing.contentWidth
  local contentHeight = sizing.contentHeight
  local threadHeight = sizing.threadHeight
  local searchHeight = sizing.searchHeight
  local searchMargin = sizing.searchMargin
  local searchTotalHeight = sizing.searchTotalHeight
  local contactsListHeight = sizing.contactsListHeight
  local contactsHandleWidth = LayoutMetrics.GetContactsResizeHandleWidth(Theme)
  local _, _, searchClearButtonSize = LayoutMetrics.ContactsSearchMetrics(Theme)

  local dividerColor = Theme.COLORS.divider or { 0.15, 0.16, 0.22, 0.60 }
  local strongDividerColor = { dividerColor[1], dividerColor[2], dividerColor[3], 1 }
  local composerBorderColor = Theme.COLORS.composer_pane_border or strongDividerColor
  local contactsSectionBorderColor = Theme.COLORS.contacts_border_right or Theme.COLORS.contacts_divider or dividerColor
  local strongContactsBorderColor = {
    contactsSectionBorderColor[1],
    contactsSectionBorderColor[2],
    contactsSectionBorderColor[3],
    contactsSectionBorderColor[4] or 1,
  }

  -- Stage 2 + 3 of BasicFrameTemplateWithInset migration: anchor content
  -- inside the template's Inset frame and dual-anchor (TOPLEFT + BOTTOMLEFT)
  -- so the contacts pane auto-fills Inset's height. Without dual-anchor the
  -- pane uses a stale `initialState.height - TOP_BAR_HEIGHT` height that's
  -- shorter than Inset, leaving a visible gap at the bottom of the window.
  local contactsPane = factory.CreateFrame("Frame", nil, frame.Inset or frame)
  contactsPane:SetSize(contactsWidth, contactsHeight)
  -- Same 8px left + 24px top offset under both chromes — only the chrome
  -- itself is conditional on Azeroth, layout sizes/positions stay uniform.
  contactsPane:SetPoint("TOPLEFT", frame.Inset or frame, "TOPLEFT", 6, -Theme.LAYOUT.TOP_BAR_HEIGHT)
  contactsPane:SetPoint("BOTTOMLEFT", frame.Inset or frame, "BOTTOMLEFT", 7, 6)

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
    point = { "TOPLEFT", contactsPane, "TOPLEFT", 0, -searchTotalHeight - 2 },
    step = Theme.LAYOUT.CONTACT_ROW_HEIGHT,
  })
  -- Dual-anchor the scrollFrame's BOTTOMRIGHT to the pane so the viewport
  -- stops exactly at the pane border regardless of any mismatch between the
  -- calculated contactsListHeight and the pane's live dual-anchor height.
  -- Without this, the scrollFrame extends a few px past the pane bottom and
  -- the last row paints over the pane border into the window chrome.
  if contactsView.scrollFrame and contactsView.scrollFrame.SetPoint then
    contactsView.scrollFrame:SetPoint("BOTTOMRIGHT", contactsPane, "BOTTOMRIGHT", 0, 0)
  end

  local contentParent = frame.Inset or frame
  local contactsDivider = contentParent:CreateTexture(nil, "BORDER")
  contactsDivider:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", 0, 0)
  contactsDivider:SetSize(Theme.DIVIDER_THICKNESS, contactsHeight)
  applyColorTexture(contactsDivider, Theme.COLORS.contacts_divider or Theme.COLORS.divider)

  -- Drag handle over the contacts divider for contacts-only resizing.
  local contactsResizeHandle = factory.CreateFrame("Frame", nil, contentParent)
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

  local contentPane = factory.CreateFrame("Frame", nil, contentParent)
  contentPane:SetSize(contentWidth, contentHeight)
  contentPane:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", Theme.DIVIDER_THICKNESS, 0)
  -- Dual-anchor BOTTOMRIGHT to Inset with 5px right + 10px bottom margins
  -- so neither the composer container nor the conversation header overlap
  -- the window's border.
  contentPane:SetPoint(
    "BOTTOMRIGHT",
    contentParent,
    "BOTTOMRIGHT",
    -Theme.LAYOUT.CONTENT_PANE_RIGHT_INSET,
    Theme.LAYOUT.CONTENT_PANE_BOTTOM_INSET
  )

  local threadPane = factory.CreateFrame("Frame", nil, contentPane)
  threadPane:SetSize(contentWidth, threadHeight)
  threadPane:SetPoint("TOPLEFT", contentPane, "TOPLEFT", 0, 0)
  local headerDivider = nil

  local composerPane = factory.CreateFrame("Frame", nil, contentPane)
  composerPane:SetSize(contentWidth, Theme.COMPOSER_HEIGHT)
  composerPane:SetPoint("BOTTOMLEFT", contentPane, "BOTTOMLEFT", 0, -4)
  -- Dual-anchor both edges flush with contentPane so the composer container
  -- extends to the window's bottom-right corner. The resize grip sits on
  -- the outer frame at a higher frame level and visually overlays the
  -- composer corner instead of pushing the pane inward.
  composerPane:SetPoint("BOTTOMRIGHT", contentPane, "BOTTOMRIGHT", 0, -4)
  threadPane:SetPoint("BOTTOMRIGHT", composerPane, "TOPRIGHT", 0, Theme.DIVIDER_THICKNESS)
  local composerPaneBorder =
    UIHelpers.createBorderBox(composerPane, composerBorderColor, Theme.DIVIDER_THICKNESS, "BORDER")
  local composerDivider = composerPaneBorder and composerPaneBorder.top or nil

  local optionsPanelLayout = OptionsPanelLayout.Build(factory, contentParent, initialState, {
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
