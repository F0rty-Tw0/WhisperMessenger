local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture
local createOptionButton = UIHelpers.createOptionButton

local LayoutBuilder = {}

-- Creates all layout panes inside the window frame.
--
-- factory      : frame factory
-- frame        : the outer window frame (from ChromeBuilder)
-- initialState : { width, height }
-- options      : (unused currently, reserved for future options)
--
-- Returns:
--   contactsPane, contactsDivider, contentPane, headerDivider,
--   threadPane, composerPane, composerDivider,
--   optionsPanel, optionsHeader, optionsHint,
--   resetWindowButton, resetIconButton, clearAllChatsButton,
--   contactsView (the ScrollView for the contacts list)
function LayoutBuilder.Build(factory, frame, initialState, _options)
  local contactsHeight = initialState.height - Theme.TOP_BAR_HEIGHT
  local contentWidth = initialState.width - Theme.CONTACTS_WIDTH - Theme.DIVIDER_THICKNESS
  local contentHeight = initialState.height - Theme.TOP_BAR_HEIGHT
  local threadHeight = contentHeight - Theme.COMPOSER_HEIGHT - Theme.DIVIDER_THICKNESS

  local contactsPane = factory.CreateFrame("Frame", nil, frame)
  contactsPane:SetSize(Theme.CONTACTS_WIDTH, contactsHeight)
  contactsPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Theme.TOP_BAR_HEIGHT)

  -- Contacts pane background (slightly lighter than main window)
  local contactsPaneBg = contactsPane:CreateTexture(nil, "BACKGROUND")
  contactsPaneBg:SetAllPoints(contactsPane)
  applyColorTexture(contactsPaneBg, Theme.COLORS.bg_secondary)

  local contactsView = ScrollView.Create(factory, contactsPane, {
    width = Theme.CONTACTS_WIDTH,
    height = contactsHeight,
    step = Theme.LAYOUT.CONTACT_ROW_HEIGHT,
  })

  local contactsDivider = frame:CreateTexture(nil, "BORDER")
  contactsDivider:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", 0, 0)
  contactsDivider:SetSize(Theme.DIVIDER_THICKNESS, contactsHeight)
  applyColorTexture(contactsDivider, Theme.COLORS.divider)

  local contentPane = factory.CreateFrame("Frame", nil, frame)
  contentPane:SetSize(contentWidth, contentHeight)
  contentPane:SetPoint(
    "TOPLEFT",
    frame,
    "TOPLEFT",
    Theme.CONTACTS_WIDTH + Theme.DIVIDER_THICKNESS,
    -Theme.TOP_BAR_HEIGHT
  )

  local headerDivider = frame:CreateTexture(nil, "BORDER")
  headerDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Theme.TOP_BAR_HEIGHT)
  headerDivider:SetSize(initialState.width, Theme.DIVIDER_THICKNESS)
  applyColorTexture(headerDivider, Theme.COLORS.divider)

  local threadPane = factory.CreateFrame("Frame", nil, contentPane)
  threadPane:SetSize(contentWidth, threadHeight)
  threadPane:SetPoint("TOPLEFT", contentPane, "TOPLEFT", 0, 0)

  local composerPane = factory.CreateFrame("Frame", nil, contentPane)
  composerPane:SetSize(contentWidth, Theme.COMPOSER_HEIGHT)
  composerPane:SetPoint("BOTTOMLEFT", contentPane, "BOTTOMLEFT", 0, 0)

  local composerDivider = contentPane:CreateTexture(nil, "BORDER")
  composerDivider:SetPoint("BOTTOMLEFT", threadPane, "BOTTOMLEFT", 0, -Theme.DIVIDER_THICKNESS)
  composerDivider:SetSize(contentWidth, Theme.DIVIDER_THICKNESS)
  applyColorTexture(composerDivider, Theme.COLORS.divider)

  -- Options overlay container (hides contacts + content when visible)
  local optionsPanel = factory.CreateFrame("Frame", nil, frame)
  optionsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Theme.TOP_BAR_HEIGHT)
  optionsPanel:SetSize(initialState.width, initialState.height - Theme.TOP_BAR_HEIGHT)

  -- Left sidebar menu
  local optionsMenu = factory.CreateFrame("Frame", nil, optionsPanel)
  optionsMenu:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 0, 0)
  optionsMenu:SetSize(Theme.CONTACTS_WIDTH, initialState.height - Theme.TOP_BAR_HEIGHT)

  local optionsMenuBg = optionsMenu:CreateTexture(nil, "BACKGROUND")
  optionsMenuBg:SetAllPoints(optionsMenu)
  applyColorTexture(optionsMenuBg, Theme.COLORS.bg_secondary)

  local menuPadding = Theme.CONTENT_PADDING

  local optionsHeader = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  optionsHeader:SetPoint("TOPLEFT", optionsMenu, "TOPLEFT", menuPadding, -menuPadding)
  optionsHeader:SetText("Options")

  -- Divider between menu and content
  local optionsMenuDivider = optionsPanel:CreateTexture(nil, "BORDER")
  optionsMenuDivider:SetPoint("TOPLEFT", optionsMenu, "TOPRIGHT", 0, 0)
  optionsMenuDivider:SetSize(Theme.DIVIDER_THICKNESS, initialState.height - Theme.TOP_BAR_HEIGHT)
  applyColorTexture(optionsMenuDivider, Theme.COLORS.divider)

  -- Right content pane for settings views (scrollable)
  local optionsContentWidth = initialState.width - Theme.CONTACTS_WIDTH - Theme.DIVIDER_THICKNESS
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
  local tabLayout = { height = Theme.LAYOUT.OPTION_BUTTON_HEIGHT, width = Theme.CONTACTS_WIDTH - (menuPadding * 2) }
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
  local btnLayout = { height = btnH, width = Theme.CONTACTS_WIDTH - (menuPadding * 2) }

  local clearAllChatsButton = createOptionButton(factory, optionsMenu, "Clear All Chats", dangerColors, btnLayout)
  clearAllChatsButton:SetPoint("BOTTOMLEFT", optionsMenu, "BOTTOMLEFT", menuPadding, menuPadding)

  local resetIconButton = createOptionButton(factory, optionsMenu, "Reset Icon Position", normalColors, btnLayout)
  resetIconButton:SetPoint("BOTTOMLEFT", clearAllChatsButton, "TOPLEFT", 0, btnSpacing)

  local resetWindowButton = createOptionButton(factory, optionsMenu, "Reset Window Position", normalColors, btnLayout)
  resetWindowButton:SetPoint("BOTTOMLEFT", resetIconButton, "TOPLEFT", 0, btnSpacing)

  local optionsHint = optionsMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  optionsHint:SetPoint("BOTTOMLEFT", resetWindowButton, "TOPLEFT", 0, menuPadding)
  optionsHint:SetText("Reset positions or clear all conversation history.")

  return {
    contactsPane = contactsPane,
    contactsDivider = contactsDivider,
    contentPane = contentPane,
    headerDivider = headerDivider,
    threadPane = threadPane,
    composerPane = composerPane,
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
    contactsView = contactsView,
  }
end

-- Recalculate all pane sizes after a frame resize.
-- layout: the table returned by LayoutBuilder.Build
-- width, height: new frame dimensions
function LayoutBuilder.Relayout(layout, width, height)
  local contactsH = height - Theme.TOP_BAR_HEIGHT
  local contentW = width - Theme.CONTACTS_WIDTH - Theme.DIVIDER_THICKNESS
  local contentH = contactsH
  local threadH = contentH - Theme.COMPOSER_HEIGHT - Theme.DIVIDER_THICKNESS

  layout.contactsPane:SetSize(Theme.CONTACTS_WIDTH, contactsH)
  layout.contactsDivider:SetSize(Theme.DIVIDER_THICKNESS, contactsH)
  layout.contentPane:SetSize(contentW, contentH)
  layout.headerDivider:SetSize(width, Theme.DIVIDER_THICKNESS)
  layout.threadPane:SetSize(contentW, threadH)
  layout.composerPane:SetSize(contentW, Theme.COMPOSER_HEIGHT)
  layout.composerDivider:SetSize(contentW, Theme.DIVIDER_THICKNESS)

  -- Resize contacts scroll view (viewport + scrollbar only; content height is
  -- managed by ContactsList.Refresh / fillViewport — shrinking it here would
  -- collapse the scroll range and trigger a checkLoadMore cascade).
  local cv = layout.contactsView
  if cv then
    cv.scrollFrame:SetSize(Theme.CONTACTS_WIDTH, contactsH)
    cv.scrollBar:SetHeight(contactsH)
    cv.viewportHeight = contactsH
  end

  -- Resize options overlay to match new window dimensions
  local optionsH = contactsH
  local optionsContentW = contentW
  layout.optionsPanel:SetSize(width, optionsH)
  layout.optionsMenu:SetSize(Theme.CONTACTS_WIDTH, optionsH)
  layout.optionsMenuDivider:SetSize(Theme.DIVIDER_THICKNESS, optionsH)
  layout.optionsContentPane:SetSize(optionsContentW, optionsH)

  -- Resize options scroll view
  local osv = layout.optionsScrollView
  if osv then
    osv.scrollFrame:SetSize(optionsContentW, optionsH)
    osv.scrollBar:SetHeight(optionsH)
    osv.viewportHeight = optionsH
    osv.totalWidth = optionsContentW
    local Metrics = ns.ScrollViewMetrics or require("WhisperMessenger.UI.ScrollView.Metrics")
    Metrics.RefreshMetrics(osv, osv.content.height or 420)
  end
end

ns.MessengerWindowLayoutBuilder = LayoutBuilder

return LayoutBuilder
