local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local LayoutMetrics = ns.MessengerWindowLayoutMetrics or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local ContactsSearchUI = ns.MessengerWindowLayoutContactsSearchUI or require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.ContactsSearchUI")
local applyColorTexture = UIHelpers.applyColorTexture

local ContactsSection = {}

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

  local dividerColor = theme.COLORS.divider or { 0.15, 0.16, 0.22, 0.60 }
  local contactsSectionBorderColor = theme.COLORS.contacts_border_right or theme.COLORS.contacts_divider or dividerColor
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
  local contactsPaneParent = frame.Inset or frame
  local contactsPane = factory.CreateFrame("Frame", nil, contactsPaneParent)
  contactsPane:SetSize(contactsWidth, contactsHeight)
  -- Same 8px left + 24px top offset under both chromes — only the chrome
  -- itself is conditional on Azeroth, layout sizes/positions stay uniform.
  contactsPane:SetPoint("TOPLEFT", contactsPaneParent, "TOPLEFT", 6, -theme.LAYOUT.TOP_BAR_HEIGHT)
  contactsPane:SetPoint("BOTTOMLEFT", contactsPaneParent, "BOTTOMLEFT", 7, 6)

  -- Contacts pane background and section border
  local contactsPaneBg = contactsPane:CreateTexture(nil, "BACKGROUND")
  contactsPaneBg:SetAllPoints(contactsPane)
  applyTexture(contactsPaneBg, theme.COLORS.bg_secondary)
  local contactsPaneEdges = uiHelpers.createBorderBox(
    contactsPane,
    strongContactsBorderColor,
    theme.DIVIDER_THICKNESS,
    "BORDER",
    { top = false, left = true, right = true, bottom = true }
  )
  local contactsHeaderDivider = contactsPane:CreateTexture(nil, "BORDER")
  contactsHeaderDivider:SetPoint("TOPLEFT", contactsPane, "TOPLEFT", 0, 0)
  contactsHeaderDivider:SetPoint("TOPRIGHT", contactsPane, "TOPRIGHT", 0, 0)
  contactsHeaderDivider:SetHeight(theme.DIVIDER_THICKNESS)
  applyTexture(contactsHeaderDivider, dividerColor)
  local contactsPaneBorder = {
    top = contactsHeaderDivider,
    left = contactsPaneEdges and contactsPaneEdges.left or nil,
    right = contactsPaneEdges and contactsPaneEdges.right or nil,
    bottom = contactsPaneEdges and contactsPaneEdges.bottom or nil,
  }
  local contactsRightBorder = contactsPaneBorder.right

  local contactsSearch = contactsSearchUI.Build(factory, contactsPane, {
    contactsWidth = contactsWidth,
    searchMargin = searchMargin,
    searchHeight = searchHeight,
    searchClearButtonSize = searchClearButtonSize,
    dividerColor = dividerColor,
    theme = theme,
    uiHelpers = uiHelpers,
    applyColorTexture = applyTexture,
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

  local contentParent = frame.Inset or frame
  local contactsDivider = contentParent:CreateTexture(nil, "BORDER")
  contactsDivider:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", 0, 0)
  contactsDivider:SetSize(theme.DIVIDER_THICKNESS, contactsHeight)
  applyTexture(contactsDivider, theme.COLORS.contacts_divider or theme.COLORS.divider)

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
  applyTexture(contactsResizeHandleBg, { 0, 0, 0, 0 })
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
    applyTexture(edge, { 0, 0, 0, 0 })
    edge:Hide()
  end
  contactsResizeHandle.outline = contactsResizeOutline

  return {
    contactsPane = contactsPane,
    contactsPaneBg = contactsPaneBg,
    contactsPaneEdges = contactsPaneEdges,
    contactsPaneBorder = contactsPaneBorder,
    contactsRightBorder = contactsRightBorder,
    contactsHeaderDivider = contactsHeaderDivider,
    contactsSearch = contactsSearch,
    contactsView = contactsView,
    contactsDivider = contactsDivider,
    contactsResizeHandle = contactsResizeHandle,
    contactsHandleWidth = contactsHandleWidth,
  }
end

ns.MessengerWindowLayoutContactsSection = ContactsSection

return ContactsSection
