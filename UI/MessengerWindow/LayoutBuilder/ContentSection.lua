local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local ContentSection = {}

function ContentSection.Build(factory, contentParent, contactsPane, sizing, options)
  options = options or {}

  local theme = options.theme
  local contactsWidth = sizing.contactsWidth
  local contentWidth = sizing.contentWidth
  local contentHeight = sizing.contentHeight
  local threadHeight = sizing.threadHeight

  local dividerColor = theme.COLORS.divider or { 0.15, 0.16, 0.22, 0.60 }
  local strongDividerColor = { dividerColor[1], dividerColor[2], dividerColor[3], 1 }
  local composerBorderColor = theme.COLORS.composer_pane_border or strongDividerColor

  local contentPane = factory.CreateFrame("Frame", nil, contentParent)
  contentPane:SetSize(contentWidth, contentHeight)
  contentPane:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", theme.DIVIDER_THICKNESS, 0)
  -- Dual-anchor BOTTOMRIGHT to Inset with 5px right + 10px bottom margins
  -- so neither the composer container nor the conversation header overlap
  -- the window's border.
  contentPane:SetPoint(
    "BOTTOMRIGHT",
    contentParent,
    "BOTTOMRIGHT",
    -theme.LAYOUT.CONTENT_PANE_RIGHT_INSET,
    theme.LAYOUT.CONTENT_PANE_BOTTOM_INSET
  )

  local threadPane = factory.CreateFrame("Frame", nil, contentPane)
  threadPane:SetSize(contentWidth, threadHeight)
  threadPane:SetPoint("TOPLEFT", contentPane, "TOPLEFT", 0, 0)

  local composerPane = factory.CreateFrame("Frame", nil, contentPane)
  composerPane:SetSize(contentWidth, theme.COMPOSER_HEIGHT)
  composerPane:SetPoint("BOTTOMLEFT", contentPane, "BOTTOMLEFT", 0, -4)
  -- Dual-anchor both edges flush with contentPane so the composer container
  -- extends to the window's bottom-right corner. The resize grip sits on
  -- the outer frame at a higher frame level and visually overlays the
  -- composer corner instead of pushing the pane inward.
  composerPane:SetPoint("BOTTOMRIGHT", contentPane, "BOTTOMRIGHT", 0, -4)

  threadPane:SetPoint("BOTTOMRIGHT", composerPane, "TOPRIGHT", 0, theme.DIVIDER_THICKNESS)

  local composerPaneBorder =
    UIHelpers.createBorderBox(composerPane, composerBorderColor, theme.DIVIDER_THICKNESS, "BORDER")
  local composerDivider = composerPaneBorder and composerPaneBorder.top or nil

  return {
    contactsWidth = contactsWidth,
    contentPane = contentPane,
    threadPane = threadPane,
    composerPane = composerPane,
    composerPaneBorder = composerPaneBorder,
    composerDivider = composerDivider,
  }
end

ns.MessengerWindowLayoutContentSection = ContentSection

return ContentSection
