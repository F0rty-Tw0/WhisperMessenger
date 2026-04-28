local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local LayoutMetrics = ns.MessengerWindowLayoutMetrics or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local LayoutApply = ns.MessengerWindowLayoutApply or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Apply")
local LayoutThemeApply = ns.MessengerWindowLayoutThemeApply or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ThemeApply")
local ContactsSection = ns.MessengerWindowLayoutContactsSection or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContactsSection")
local ContentSection = ns.MessengerWindowLayoutContentSection or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContentSection")
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
  local sizing =
    LayoutMetrics.CalculateRelayout({}, initialState.width, initialState.height, _options.contactsWidth or initialState.contactsWidth, Theme)
  local contactsWidth = sizing.contactsWidth
  local searchHeight = sizing.searchHeight
  local searchMargin = sizing.searchMargin
  local searchTotalHeight = sizing.searchTotalHeight
  local contactsListHeight = sizing.contactsListHeight

  local contactsSection = ContactsSection.Build(factory, frame, sizing, {
    theme = Theme,
  })
  local contactsPane = contactsSection.contactsPane
  local contactsPaneBg = contactsSection.contactsPaneBg
  local contactsPaneEdges = contactsSection.contactsPaneEdges
  local contactsPaneBorder = contactsSection.contactsPaneBorder
  local contactsRightBorder = contactsSection.contactsRightBorder
  local contactsHeaderDivider = contactsSection.contactsHeaderDivider
  local contactsSearch = contactsSection.contactsSearch
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
  local contactsView = contactsSection.contactsView
  local contactsDivider = contactsSection.contactsDivider
  local contactsResizeHandle = contactsSection.contactsResizeHandle
  local contactsHandleWidth = contactsSection.contactsHandleWidth

  local contentParent = frame.Inset or frame
  local contentSection = ContentSection.Build(factory, contentParent, contactsPane, sizing, {
    theme = Theme,
  })
  local contentPane = contentSection.contentPane
  local threadPane = contentSection.threadPane
  local composerPane = contentSection.composerPane
  local composerPaneBorder = contentSection.composerPaneBorder
  local composerDivider = contentSection.composerDivider
  local headerDivider = nil

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
