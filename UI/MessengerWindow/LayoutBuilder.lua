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

  local optionsPanel = factory.CreateFrame("Frame", nil, frame)
  optionsPanel:SetPoint(
    "TOPLEFT",
    frame,
    "TOPLEFT",
    Theme.CONTENT_PADDING,
    -(Theme.TOP_BAR_HEIGHT + Theme.CONTENT_PADDING)
  )
  optionsPanel:SetSize(
    initialState.width - (Theme.CONTENT_PADDING * 2),
    initialState.height - Theme.TOP_BAR_HEIGHT - (Theme.CONTENT_PADDING * 2)
  )

  local optionsHeader = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  optionsHeader:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 0, 0)
  optionsHeader:SetText("Options")

  local optionsHint = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  optionsHint:SetPoint("TOPLEFT", optionsHeader, "BOTTOMLEFT", 0, -12)
  optionsHint:SetText("Reset positions or clear all conversation history.")

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
  local btnLayout = { height = btnH, width = 200 }

  local resetWindowButton = createOptionButton(factory, optionsPanel, "Reset Window Position", normalColors, btnLayout)
  resetWindowButton:SetPoint("TOPLEFT", optionsHint, "BOTTOMLEFT", 0, -16)

  local resetIconButton = createOptionButton(factory, optionsPanel, "Reset Icon Position", normalColors, btnLayout)
  resetIconButton:SetPoint("TOPLEFT", resetWindowButton, "BOTTOMLEFT", 0, -btnSpacing)

  local clearAllChatsButton = createOptionButton(factory, optionsPanel, "Clear All Chats", dangerColors, btnLayout)
  clearAllChatsButton:SetPoint("TOPLEFT", resetIconButton, "BOTTOMLEFT", 0, -btnSpacing)

  return {
    contactsPane = contactsPane,
    contactsDivider = contactsDivider,
    contentPane = contentPane,
    headerDivider = headerDivider,
    threadPane = threadPane,
    composerPane = composerPane,
    composerDivider = composerDivider,
    optionsPanel = optionsPanel,
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
end

ns.MessengerWindowLayoutBuilder = LayoutBuilder

return LayoutBuilder
