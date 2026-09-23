local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local LayoutMetrics = ns.MessengerWindowLayoutMetrics or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local ContactsSearchUI = ns.MessengerWindowLayoutContactsSearchUI or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContactsSearchUI")
local HoverFade = ns.UIHelpersHoverFade or require("WhisperMessenger.UI.Helpers.HoverFade")
local applyColorTexture = UIHelpers.applyColorTexture

local ContactsSection = {}

local RESIZE_LINE_WIDTH = 2

function ContactsSection.Build(factory, frame, sizing, options)
  options = options or {}

  local theme = options.theme or Theme
  local layoutMetrics = options.layoutMetrics or LayoutMetrics
  local uiHelpers = options.uiHelpers or UIHelpers
  local scrollView = options.scrollView or ScrollView
  local contactsSearchUI = options.contactsSearchUI or ContactsSearchUI
  local applyTexture = options.applyColorTexture or applyColorTexture

  local contactsWidth = sizing.contactsWidth
  local contactsHeight = sizing.contactsHeight
  local searchHeight = sizing.searchHeight
  local searchMargin = sizing.searchMargin
  local searchTotalHeight = sizing.searchTotalHeight
  local contactsListHeight = sizing.contactsListHeight
  local contactsHandleWidth = layoutMetrics.GetContactsResizeHandleWidth(theme)
  local _, _, searchClearButtonSize = layoutMetrics.ContactsSearchMetrics(theme)

  -- Native WoW HUD: anchor content inside the chrome's content area and
  -- dual-anchor (TOPLEFT + BOTTOMLEFT) so the contacts pane auto-fills its
  -- parent's height. Without dual-anchor the
  -- pane uses a stale `initialState.height - TOP_BAR_HEIGHT` height that's
  -- shorter than its parent, leaving a visible gap at the bottom of the window.
  local contactsPaneParent = frame.contentArea or frame
  local contactsPane = factory.CreateFrame("Frame", nil, contactsPaneParent)
  contactsPane:SetSize(contactsWidth, contactsHeight)
  -- Edge insets from the window edge (Theme.LAYOUT).
  local L = theme.LAYOUT
  -- Native WoW HUD: the content area already clears the template title bar,
  -- so content starts at its top and lets the template texture show through.
  local nativeChrome = frame.contentArea ~= nil
  local contactsTopOffset = nativeChrome and 0 or -L.TOP_BAR_HEIGHT
  contactsPane:SetPoint("TOPLEFT", contactsPaneParent, "TOPLEFT", L.CONTACTS_PANE_LEFT_INSET, contactsTopOffset)
  contactsPane:SetPoint("BOTTOMLEFT", contactsPaneParent, "BOTTOMLEFT", L.CONTACTS_PANE_BOTTOM_LEFT_INSET, L.CONTACTS_PANE_BOTTOM_INSET)

  -- Contacts pane background
  local contactsPaneBg = contactsPane:CreateTexture(nil, "BACKGROUND")
  contactsPaneBg:SetAllPoints(contactsPane)
  applyTexture(contactsPaneBg, nativeChrome and UIHelpers.TRANSPARENT or theme.COLORS.bg_secondary)

  local contactsSearch = contactsSearchUI.Build(factory, contactsPane, {
    contactsWidth = contactsWidth,
    searchMargin = searchMargin,
    searchHeight = searchHeight,
    searchClearButtonSize = searchClearButtonSize,
    theme = theme,
    uiHelpers = uiHelpers,
    nativeChrome = nativeChrome,
  })

  local contactsView = scrollView.Create(factory, contactsPane, {
    width = contactsWidth,
    height = contactsListHeight,
    point = { "TOPLEFT", contactsPane, "TOPLEFT", 0, -searchTotalHeight - 2 },
    step = theme.LAYOUT.CONTACT_ROW_HEIGHT,
  })
  -- Dual-anchor the scrollFrame's BOTTOMRIGHT to the pane so the viewport
  -- stops exactly at the pane border regardless of any mismatch between the
  -- calculated contactsListHeight and the pane's live dual-anchor height.
  -- Without this, the scrollFrame extends a few px past the pane bottom and
  -- the last row paints over the pane border into the window chrome.
  if contactsView.scrollFrame and contactsView.scrollFrame.SetPoint then
    contactsView.scrollFrame:SetPoint("BOTTOMRIGHT", contactsPane, "BOTTOMRIGHT", 0, 0)
  end

  local contentParent = contactsPaneParent
  local contactsDivider = contentParent:CreateTexture(nil, "BORDER")
  contactsDivider:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", 0, 0)
  contactsDivider:SetSize(uiHelpers.hairlineThickness(contentParent, theme.DIVIDER_THICKNESS), contactsHeight)
  uiHelpers.snapToPixelGrid(contactsDivider)
  applyTexture(contactsDivider, theme.COLORS.contacts_divider or theme.COLORS.divider)
  contactsDivider:Show()

  -- Drag handle over the contacts divider for contacts-only resizing.
  local contactsResizeHandle = factory.CreateFrame("Frame", nil, contentParent)
  contactsResizeHandle:SetSize(contactsHandleWidth, contactsHeight)
  contactsResizeHandle:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", -math.floor(contactsHandleWidth / 2), 0)
  contactsResizeHandle:EnableMouse(true)
  if contactsResizeHandle.SetFrameLevel and frame.GetFrameLevel then
    contactsResizeHandle:SetFrameLevel(frame:GetFrameLevel() + 15)
  end
  -- The hit zone stays invisible; hover/drag fades in this 2px line over the
  -- hairline divider.
  local contactsResizeLine = contactsResizeHandle:CreateTexture(nil, "OVERLAY")
  contactsResizeLine:SetPoint("TOP", contactsDivider, "TOP", 0, 0)
  contactsResizeLine:SetPoint("BOTTOM", contactsDivider, "BOTTOM", 0, 0)
  contactsResizeLine:SetWidth(RESIZE_LINE_WIDTH)
  contactsResizeLine:Hide()
  contactsResizeHandle.line = contactsResizeLine
  contactsResizeHandle.lineFade = HoverFade.Attach(contactsResizeLine)

  return {
    contactsPane = contactsPane,
    contactsPaneBg = contactsPaneBg,
    contactsSearch = contactsSearch,
    contactsView = contactsView,
    contactsDivider = contactsDivider,
    contactsResizeHandle = contactsResizeHandle,
    contactsHandleWidth = contactsHandleWidth,
    contactsTopOffset = contactsTopOffset,
    nativeChrome = nativeChrome,
  }
end

ns.MessengerWindowLayoutContactsSection = ContactsSection

return ContactsSection
