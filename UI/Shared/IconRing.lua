local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The look the widget and the minimap button share, chosen by the Native
-- WoW HUD style. Off: the full logo alone. Classic and Modern: the logo
-- without its painted rim, inside a hi-res, centred redraw of that HUD's
-- minimap button ring (Blizzard's MiniMap-TrackingBorder from Classic Era
-- and from retail). The rings are grayscale so the theme's ring color tints
-- them. Sizes are relative to the button: the ring's outer edge meets the
-- button's edge (its shadow reaches past it), and the logo's disc runs just
-- under the ring's inner edge so nothing shows between them.
local IconRing = {}

local MEDIA = "Interface\\AddOns\\WhisperMessenger\\Media\\"

IconRing.LOGO = MEDIA .. "icon.png"
IconRing.RIMLESS_LOGO = MEDIA .. "icon_rimless.png"
IconRing.RING = {
  classic = MEDIA .. "icon_ring_classic.png",
  modern = MEDIA .. "icon_ring_modern.png",
}
-- The ring art's canvas spans 22 units of radius around a ring whose outer
-- edge is at 16; the logo's disc reaches 12.8, under the ring's inner edge.
IconRing.RING_SCALE = 44 / 32
IconRing.LOGO_SCALE = 25.6 / 32

local HUD_RINGS = { classic = "classic", retail = "modern" }

-- The ring for a Native WoW HUD style ("off", "classic", "retail"), or nil.
function IconRing.Kind(hudStyle)
  return HUD_RINGS[hudStyle]
end

-- The theme's ring color, fully opaque (the ring's art carries the shading).
function IconRing.RingColor(colors)
  local c = colors.toggle_icon_ring or colors.accent or { 1, 1, 1 }
  return { c[1], c[2], c[3], 1 }
end

local function centre(region, frame, size)
  size = math.floor(size) -- whole pixels, as the widget always sized its logo
  region:ClearAllPoints()
  region:SetSize(size, size)
  region:SetPoint("CENTER", frame, "CENTER", 0, 0)
end

-- parts: { frame, icon, ring }; size: the button's size; plainRatio: the
-- logo's size against the button when there is no ring.
function IconRing.Apply(parts, kind, size, plainRatio)
  local ringTexture = IconRing.RING[kind]
  if ringTexture then
    parts.icon:SetTexture(IconRing.RIMLESS_LOGO)
    centre(parts.icon, parts.frame, size * IconRing.LOGO_SCALE)
    parts.ring:SetTexture(ringTexture)
    centre(parts.ring, parts.frame, size * IconRing.RING_SCALE)
    parts.ring:Show()
  else
    parts.icon:SetTexture(IconRing.LOGO)
    centre(parts.icon, parts.frame, size * (plainRatio or 1))
    parts.ring:Hide()
  end
end

ns.IconRing = IconRing
return IconRing
