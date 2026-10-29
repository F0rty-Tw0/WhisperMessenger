local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- How the minimap button is framed. "classic" and "modern" copy LibDBIcon's
-- buttons (the minimap buttons most addons use, LibDBIcon-1.0 r57): the
-- game's MiniMap-TrackingBorder ring over UI-Minimap-Background, in its
-- Classic layout (no addon compartment, e.g. Classic Era) or its Modern
-- layout (retail and WoW Forever, which have the compartment). "plain" is
-- the addon's own dark disc with a thin hoop, for players who turn the ring
-- off. Positions are centres measured from the button's top-left corner.
local Look = {}

Look.BORDER_TEXTURE = "Interface\\Minimap\\MiniMap-TrackingBorder"
Look.BACKGROUND_TEXTURE = "Interface\\Minimap\\UI-Minimap-Background"
Look.HIGHLIGHT_TEXTURE = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
Look.PLAIN_BORDER_TEXTURE = "Interface\\COMMON\\RingBorder"
Look.PLAIN_BACKGROUND_TEXTURE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

local GLYPH_SCALE = 1.2 -- the bubble art has empty margins; LibDBIcon icons are cropped
local WHITE = { 1, 1, 1, 1 }
local PLAIN_BG_COLOR = { 0.08, 0.08, 0.08, 0.85 }
local PLAIN_BORDER_COLOR = { 0.3, 0.3, 0.3, 0.4 }

local LAYOUTS = {
  classic = {
    size = 31,
    border = 53,
    background = { size = 20, x = 17, y = -15 },
    icon = { size = 17, x = 15.5, y = -14.5 },
  },
  modern = {
    size = 31,
    border = 50,
    background = { size = 24, x = 15.5, y = -15.5 },
    icon = { size = 18, x = 15.5, y = -15.5 },
  },
  plain = { size = 30, glyphRatio = 0.8 },
}

-- enabled: the ring setting (nil = on); style: "auto" (nil), "classic" or "modern".
function Look.Resolve(enabled, style)
  if enabled == false then
    return "plain"
  end
  if style == "classic" or style == "modern" then
    return style
  end
  return _G.AddonCompartmentFrame and "modern" or "classic"
end

-- The colors desaturation restores for the background and the border.
function Look.Colors(kind)
  if kind == "plain" then
    return PLAIN_BG_COLOR, PLAIN_BORDER_COLOR
  end
  return WHITE, WHITE
end

local function setShown(region, shown)
  if shown then
    region:Show()
  else
    region:Hide()
  end
end

-- parts: { frame, background, border, icon, highlight }.
function Look.Apply(parts, kind)
  local layout = LAYOUTS[kind] or LAYOUTS.plain
  local frame, background, border, icon = parts.frame, parts.background, parts.border, parts.icon
  frame:SetSize(layout.size, layout.size)
  background:ClearAllPoints()
  border:ClearAllPoints()
  icon:ClearAllPoints()

  if kind == "plain" then
    background:SetTexture(Look.PLAIN_BACKGROUND_TEXTURE)
    background:SetAllPoints(frame)
    border:SetTexture(Look.PLAIN_BORDER_TEXTURE)
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    local glyph = layout.size * layout.glyphRatio
    icon:SetSize(glyph, glyph)
    icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
    setShown(parts.highlight, false)
    return
  end

  background:SetTexture(Look.BACKGROUND_TEXTURE)
  background:SetSize(layout.background.size, layout.background.size)
  background:SetPoint("CENTER", frame, "TOPLEFT", layout.background.x, layout.background.y)
  border:SetTexture(Look.BORDER_TEXTURE)
  border:SetSize(layout.border, layout.border)
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  local glyph = layout.icon.size * GLYPH_SCALE
  icon:SetSize(glyph, glyph)
  icon:SetPoint("CENTER", frame, "TOPLEFT", layout.icon.x, layout.icon.y)
  setShown(parts.highlight, true)
end

ns.MinimapButtonLook = Look
return Look
