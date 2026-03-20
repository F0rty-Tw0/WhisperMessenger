local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule

local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")
local ScrollView = loadModule("WhisperMessenger.UI.ScrollView", "ScrollView")
local UIHelpers = loadModule("WhisperMessenger.UI.Helpers", "UIHelpers")
local applyColorTexture = UIHelpers.applyColorTexture

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
--   resetWindowButton, resetIconButton,
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
  optionsHint:SetText("Reset the messenger and icon to their default positions.")

  local resetWindowButton = factory.CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
  resetWindowButton:SetSize(180, 24)
  resetWindowButton:SetPoint("TOPLEFT", optionsHint, "BOTTOMLEFT", 0, -16)
  resetWindowButton:SetText("Reset Window Position")

  local resetIconButton = factory.CreateFrame("Button", nil, optionsPanel, "UIPanelButtonTemplate")
  resetIconButton:SetSize(160, 24)
  resetIconButton:SetPoint("TOPLEFT", resetWindowButton, "BOTTOMLEFT", 0, -10)
  resetIconButton:SetText("Reset Icon Position")

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
    contactsView = contactsView,
  }
end

ns.MessengerWindowLayoutBuilder = LayoutBuilder

return LayoutBuilder
