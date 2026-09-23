local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ContentSection = {}

function ContentSection.Build(factory, contentParent, contactsPane, sizing, options)
  options = options or {}

  local theme = options.theme
  local contactsWidth = sizing.contactsWidth
  local contentWidth = sizing.contentWidth
  local contentHeight = sizing.contentHeight
  local threadHeight = sizing.threadHeight

  local contentPane = factory.CreateFrame("Frame", nil, contentParent)
  contentPane:SetSize(contentWidth, contentHeight)
  contentPane:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", theme.DIVIDER_THICKNESS, 0)
  -- Dual-anchor BOTTOMRIGHT to the parent with the right/bottom insets
  -- (Theme.LAYOUT) so neither the composer container nor the conversation
  -- header overlap the window's border.
  contentPane:SetPoint("BOTTOMRIGHT", contentParent, "BOTTOMRIGHT", -theme.LAYOUT.CONTENT_PANE_RIGHT_INSET, theme.LAYOUT.CONTENT_PANE_BOTTOM_INSET)

  local threadPane = factory.CreateFrame("Frame", nil, contentPane)
  threadPane:SetSize(contentWidth, threadHeight)
  threadPane:SetPoint("TOPLEFT", contentPane, "TOPLEFT", 0, 0)

  local composerPane = factory.CreateFrame("Frame", nil, contentPane)
  composerPane:SetSize(contentWidth, theme.COMPOSER_HEIGHT)
  composerPane:SetPoint("BOTTOMLEFT", contentPane, "BOTTOMLEFT", 0, 0)
  -- Dual-anchor both edges flush with contentPane so the composer container
  -- extends to the window's bottom-right corner. The resize grip sits on
  -- the outer frame at a higher frame level and visually overlays the
  -- composer corner instead of pushing the pane inward.
  composerPane:SetPoint("BOTTOMRIGHT", contentPane, "BOTTOMRIGHT", 0, 0)

  threadPane:SetPoint("BOTTOMRIGHT", composerPane, "TOPRIGHT", 0, theme.DIVIDER_THICKNESS)

  return {
    contactsWidth = contactsWidth,
    contentPane = contentPane,
    threadPane = threadPane,
    composerPane = composerPane,
  }
end

ns.MessengerWindowLayoutContentSection = ContentSection

return ContentSection
