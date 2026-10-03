local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Base = ns.UIHelpersBase or require("WhisperMessenger.UI.Helpers.Base")
local HoverFade = ns.UIHelpersHoverFade or require("WhisperMessenger.UI.Helpers.HoverFade")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")

-- Modern settings-nav list item, styled like a contact row: no box at rest,
-- left-aligned secondary text, faint white wash on hover, and when selected
-- an accent fade from the left edge plus a thin accent bar. Parts are created
-- once per button; Paint only recolors and toggles. Under the Native WoW HUD
-- it highlights like the contact rows: Blizzard list art, no accent bar.
local NavItem = {}

NavItem.PADDING_X = 12
NavItem.ICON_SIZE = 16
NavItem.ICON_GAP = 8

-- iconPath (optional): the page glyph left of the label, modern look only;
-- the Native WoW HUD list stays text-only like Blizzard's own.
function NavItem.Attach(button, iconPath)
  local selection = button:CreateTexture(nil, "BACKGROUND", nil, 1)
  selection:SetAllPoints(button)
  selection:Hide()
  local hover = button:CreateTexture(nil, "BACKGROUND", nil, 2)
  hover:SetAllPoints(button)
  hover:Hide()
  if Hud.IsOn() then
    NativeArt.AttachList(selection, hover)
    return { selection = selection, hover = hover, hoverFade = HoverFade.Attach(hover), native = true }
  end
  local bar = button:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
  bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
  bar:Hide()
  local icon
  if iconPath then
    icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(NavItem.ICON_SIZE, NavItem.ICON_SIZE)
    icon:SetPoint("LEFT", button, "LEFT", NavItem.PADDING_X, 0)
    icon:SetTexture(iconPath)
  end
  return { selection = selection, hover = hover, hoverFade = HoverFade.Attach(hover), bar = bar, icon = icon }
end

function NavItem.Paint(nav, label, active, hovered)
  local colors = Theme.COLORS
  if nav.native then
    NativeArt.TintList(nav.selection, nav.hoverFade, colors)
  else
    Base.applyHorizontalFade(nav.selection, colors.bg_contact_selected)
    nav.bar:SetWidth(Theme.LAYOUT.CONTACT_ACCENT_BAR_W)
    Base.applyColorTexture(nav.bar, colors.accent_bar)
    nav.bar:SetShown(active)
    nav.hoverFade.paintColor(colors.bg_contact_hover)
  end
  nav.selection:SetShown(active)
  nav.hoverFade.set(hovered and not active)
  local textColor = (active or hovered) and colors.text_primary or colors.text_secondary
  Base.setTextColor(label, textColor)
  if nav.icon then
    Base.applyVertexColor(nav.icon, textColor)
  end
end

ns.UIHelpersNavItem = NavItem
return NavItem
