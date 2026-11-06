local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The phone layout's filmstrip: the contacts and chat panes sit side by side
-- inside a window-sized viewport, and moving the contacts pane moves both.
-- layout.phoneProgress is the strip's position: 0 list, 1 chat.
local PhoneViewport = {}

function PhoneViewport.Build(factory, parent, topOffset, theme)
  local L = theme.LAYOUT
  local viewport = factory.CreateFrame("Frame", nil, parent)
  viewport:SetPoint("TOPLEFT", parent, "TOPLEFT", L.CONTACTS_PANE_LEFT_INSET, topOffset)
  viewport:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -L.CONTENT_PANE_RIGHT_INSET, L.CONTENT_PANE_BOTTOM_INSET)
  return viewport
end

-- Re-anchors the strip at layout.phoneProgress. The panes keep their widths;
-- their heights follow the viewport.
function PhoneViewport.Place(layout)
  local viewport = layout.phoneViewport
  local contactsPane = layout.contactsPane
  local contentPane = layout.contentPane
  local width = contactsPane:GetWidth() or 0
  local x = -width * (layout.phoneProgress or 0)

  contactsPane:ClearAllPoints()
  contactsPane:SetPoint("TOPLEFT", viewport, "TOPLEFT", x, 0)
  contactsPane:SetPoint("BOTTOMLEFT", viewport, "BOTTOMLEFT", x, 0)
  contentPane:ClearAllPoints()
  contentPane:SetPoint("TOPLEFT", contactsPane, "TOPRIGHT", 0, 0)
  contentPane:SetPoint("BOTTOMLEFT", contactsPane, "BOTTOMRIGHT", 0, 0)
end

ns.MessengerWindowLayoutPhoneViewport = PhoneViewport

return PhoneViewport
