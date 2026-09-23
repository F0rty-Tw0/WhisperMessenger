local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Base = ns.UIHelpersBase or require("WhisperMessenger.UI.Helpers.Base")
local HoverFade = ns.UIHelpersHoverFade or require("WhisperMessenger.UI.Helpers.HoverFade")

-- Modern settings-nav list item, styled like a contact row: no box at rest,
-- left-aligned secondary text, faint white wash on hover, and when selected
-- an accent fade from the left edge plus a thin accent bar. Parts are created
-- once per button; Paint only recolors and toggles.
local NavItem = {}

NavItem.PADDING_X = 12

function NavItem.Attach(button)
  local selection = button:CreateTexture(nil, "BACKGROUND", nil, 1)
  selection:SetAllPoints(button)
  selection:Hide()
  local hover = button:CreateTexture(nil, "BACKGROUND", nil, 2)
  hover:SetAllPoints(button)
  hover:Hide()
  local bar = button:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  bar:Hide()
  return { selection = selection, hover = hover, hoverFade = HoverFade.Attach(hover), bar = bar }
end

function NavItem.Paint(nav, label, active, hovered)
  local colors = Theme.COLORS
  Base.applyHorizontalFade(nav.selection, colors.bg_contact_selected)
  nav.selection:SetShown(active)
  nav.bar:SetWidth(Theme.LAYOUT.CONTACT_ACCENT_BAR_W)
  Base.applyColorTexture(nav.bar, colors.accent_bar)
  nav.bar:SetShown(active)
  nav.hoverFade.paintColor(colors.bg_contact_hover)
  nav.hoverFade.set(hovered and not active)
  Base.setTextColor(label, (active or hovered) and colors.text_primary or colors.text_secondary)
end

ns.UIHelpersNavItem = NavItem
return NavItem
