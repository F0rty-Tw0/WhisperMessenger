local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture
local createOptionButton = UIHelpers.createOptionButton
local sizeValue = UIHelpers.sizeValue

local LayoutBuilder = {}

-- Clamp contacts pane width so users can resize it without collapsing the chat area.
-- windowWidth: overall window width
-- requestedContactsWidth: desired contacts pane width (or nil to use defaults)
-- theme: optional theme override for tests
function LayoutBuilder.ClampContactsWidth(windowWidth, requestedContactsWidth, theme)
  local resolvedTheme = theme or Theme
  local layout = resolvedTheme.LAYOUT or {}
  local dividerThickness = resolvedTheme.DIVIDER_THICKNESS or 1
  local defaultContactsWidth = resolvedTheme.CONTACTS_WIDTH or layout.CONTACTS_WIDTH or 300
  local minContactsWidth = layout.CONTACTS_MIN_WIDTH or resolvedTheme.CONTACTS_MIN_WIDTH or 180
  local minContentWidth = layout.CONTENT_MIN_WIDTH
    or resolvedTheme.CONTENT_MIN_WIDTH
    or ((layout.WINDOW_MIN_WIDTH or resolvedTheme.WINDOW_MIN_WIDTH or 640) - defaultContactsWidth - dividerThickness)

  local safeWindowWidth = type(windowWidth) == "number" and windowWidth or (resolvedTheme.WINDOW_WIDTH or 920)
  local maxContactsWidth = math.max(minContactsWidth, safeWindowWidth - dividerThickness - minContentWidth)
  local nextWidth = type(requestedContactsWidth) == "number" and requestedContactsWidth or defaultContactsWidth

  if nextWidth < minContactsWidth then
    nextWidth = minContactsWidth
  end
  if nextWidth > maxContactsWidth then
    nextWidth = maxContactsWidth
  end

  return nextWidth
end

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
  local contactsWidth = LayoutBuilder.ClampContactsWidth(
    initialState.width,
    _options.contactsWidth or initialState.contactsWidth,
    Theme
  )
  local contactsHeight = initialState.height - Theme.TOP_BAR_HEIGHT
  local contentWidth = initialState.width - contactsWidth - Theme.DIVIDER_THICKNESS
  local contentHeight = initialState.height - Theme.TOP_BAR_HEIGHT
  local threadHeight = contentHeight - Theme.COMPOSER_HEIGHT - Theme.DIVIDER_THICKNESS
  local contactsHandleWidth = Theme.LAYOUT.CONTACTS_RESIZE_HANDLE_WIDTH or 8

  local contactsPane = factory.CreateFrame("Frame", nil, frame)
  contactsPane:SetSize(contactsWidth, contactsHeight)
  contactsPane:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -Theme.TOP_BAR_HEIGHT)

  -- Contacts pane background (slightly lighter than main window)
  local contactsPaneBg = contactsPane:CreateTexture(nil, "BACKGROUND")
  contactsPaneBg:SetAllPoints(contactsPane)
  applyColorTexture(contactsPaneBg, Theme.COLORS.bg_secondary)

  local contactsView = ScrollView.Create(factory, contactsPane, {
    width = contactsWidth,
    height = contactsHeight,
    step = Theme.LAYOUT.CONTACT_ROW_HEIGHT,
  })

  local contactsDivider = frame:CreateTexture(nil, "BORDER")
  contactsDivider:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", 0, 0)
  contactsDivider:SetSize(Theme.DIVIDER_THICKNESS, contactsHeight)
  applyColorTexture(contactsDivider, Theme.COLORS.divider)

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

  return {
    contactsPane = contactsPane,
    contactsDivider = contactsDivider,
    contactsResizeHandle = contactsResizeHandle,
    contactsWidth = contactsWidth,
    contactsHandleWidth = contactsHandleWidth,
    menuPadding = menuPadding,
    optionsButtonHeight = btnH,
    optionsContentHeight = OPTIONS_CONTENT_HEIGHT,
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
-- requestedContactsWidth: optional target contacts pane width
-- Returns: { contactsWidth, contentWidth, contactsHeight, threadHeight }
function LayoutBuilder.Relayout(layout, width, height, requestedContactsWidth)
  local contactsWidth = LayoutBuilder.ClampContactsWidth(width, requestedContactsWidth or layout.contactsWidth, Theme)
  local contactsH = height - Theme.TOP_BAR_HEIGHT
  local contentW = width - contactsWidth - Theme.DIVIDER_THICKNESS
  local contentH = contactsH
  local threadH = contentH - Theme.COMPOSER_HEIGHT - Theme.DIVIDER_THICKNESS

  layout.contactsWidth = contactsWidth

  layout.contactsPane:SetSize(contactsWidth, contactsH)
  layout.contactsDivider:SetSize(Theme.DIVIDER_THICKNESS, contactsH)
  if layout.contactsResizeHandle then
    local handleWidth = sizeValue(layout.contactsResizeHandle, "GetWidth", "width", layout.contactsHandleWidth or 8)
    layout.contactsResizeHandle:SetSize(handleWidth, contactsH)
    if layout.contactsResizeHandle.ClearAllPoints then
      layout.contactsResizeHandle:ClearAllPoints()
    end
    layout.contactsResizeHandle:SetPoint("TOPLEFT", layout.contactsPane, "TOPRIGHT", -math.floor(handleWidth / 2), 0)
  end
  layout.contentPane:SetSize(contentW, contentH)
  if layout.contentPane.ClearAllPoints then
    layout.contentPane:ClearAllPoints()
  end
  layout.contentPane:SetPoint("TOPLEFT", layout.contactsPane, "TOPRIGHT", Theme.DIVIDER_THICKNESS, 0)
  layout.headerDivider:SetSize(width, Theme.DIVIDER_THICKNESS)
  layout.threadPane:SetSize(contentW, threadH)
  layout.composerPane:SetSize(contentW, Theme.COMPOSER_HEIGHT)
  layout.composerDivider:SetSize(contentW, Theme.DIVIDER_THICKNESS)

  -- Resize contacts scroll view while preserving its content height and scroll position.
  local cv = layout.contactsView
  if cv then
    cv.totalWidth = contactsWidth
    cv.scrollFrame:SetSize(contactsWidth, contactsH)
    cv.scrollBar:SetHeight(contactsH)
    cv.viewportHeight = contactsH
    local Metrics = ns.ScrollViewMetrics or require("WhisperMessenger.UI.ScrollView.Metrics")
    Metrics.RefreshMetrics(cv, sizeValue(cv.content, "GetHeight", "height", contactsH))
  end

  -- Resize options overlay to match new window dimensions.
  local optionsH = contactsH
  local optionsContentW = contentW
  layout.optionsPanel:SetSize(width, optionsH)
  layout.optionsMenu:SetSize(contactsWidth, optionsH)
  layout.optionsMenuDivider:SetSize(Theme.DIVIDER_THICKNESS, optionsH)
  layout.optionsContentPane:SetSize(optionsContentW, optionsH)

  local menuPadding = layout.menuPadding or Theme.CONTENT_PADDING
  local optionsButtonWidth = math.max(0, contactsWidth - (menuPadding * 2))
  local optionsButtonHeight = layout.optionsButtonHeight or Theme.LAYOUT.OPTION_BUTTON_HEIGHT
  for _, button in ipairs({
    layout.generalTab,
    layout.appearanceTab,
    layout.behaviorTab,
    layout.notificationsTab,
    layout.resetWindowButton,
    layout.resetIconButton,
    layout.clearAllChatsButton,
  }) do
    if button and button.SetSize then
      button:SetSize(optionsButtonWidth, optionsButtonHeight)
    end
  end

  -- Resize options scroll view.
  local osv = layout.optionsScrollView
  if osv then
    osv.scrollFrame:SetSize(optionsContentW, optionsH)
    osv.scrollBar:SetHeight(optionsH)
    osv.viewportHeight = optionsH
    osv.totalWidth = optionsContentW
    local Metrics = ns.ScrollViewMetrics or require("WhisperMessenger.UI.ScrollView.Metrics")
    Metrics.RefreshMetrics(osv, sizeValue(osv.content, "GetHeight", "height", layout.optionsContentHeight or 420))
  end

  return {
    contactsWidth = contactsWidth,
    contentWidth = contentW,
    contactsHeight = contactsH,
    threadHeight = threadH,
  }
end

ns.MessengerWindowLayoutBuilder = LayoutBuilder

return LayoutBuilder
