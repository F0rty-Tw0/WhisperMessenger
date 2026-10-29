local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- The look the widget and the minimap button share, chosen by the Native
-- WoW HUD style. Off: the full logo alone. Classic and Modern: the logo
-- without its painted rim inside a ring, tinted with the theme's ring color.
-- Classic uses a hi-res copy of Classic Era's minimap border; Modern uses
-- the gold portrait ring of the retail target frame, cut out of the game's
-- own art (or a hi-res redraw where the game doesn't have it). The rings
-- are grayscale (the game's art is grayed in place) so the tint colors them.
local IconRing = {}

local MEDIA = "Interface\\AddOns\\WhisperMessenger\\Media\\"
local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

IconRing.LOGO = MEDIA .. "icon.png"
IconRing.RIMLESS_LOGO = MEDIA .. "icon_rimless.png"
IconRing.RING = {
  classic = MEDIA .. "icon_ring_classic.png",
  modern = MEDIA .. "icon_ring_modern.png",
}

-- Sizes against the button: ringScale for the ring's texture (its gold or
-- outer edge meets the button's edge), logoScale for the logo, whose disc
-- must reach past goldInner (the gold's inner edge) so nothing shows
-- between them.
IconRing.LOOKS = {
  -- the copy of UI-Minimap-Border: outer edge 72.5, gold from 65.5
  classic = { ringScale = 44 / 32, logoScale = 66.5 / 72.5, goldInner = 65.5 / 72.5 },
  -- the redrawn retail minimap ring: outer edge 16, gold from 12.3
  modern = { ringScale = 44 / 32, logoScale = 0.8, goldInner = 12.3 / 16 },
  -- the target frame's ring: gold from 53.5 to 60, cut out 62 around its centre
  modernArt = { ringScale = 124 / 120, logoScale = 55 / 60, goldInner = 53.5 / 60 },
}

-- The retail target frame (2x art first). On the 2x art, 384x134, the ring
-- is centred at (313, 62) and cut out 62px around it, which leaves the
-- health and mana bars that run into it outside the circle mask.
local TARGET_ATLASES = { "ui-hud-unitframe-target-portraiton-2x", "ui-hud-unitframe-target-portraiton" }
local RING_X, RING_Y = 313 / 384, 62 / 134
local RING_RX, RING_RY = 62 / 384, 62 / 134

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

-- The target frame ring's file and texture coordinates, or nil when this
-- client doesn't have the art.
function IconRing.TargetRingArt()
  local textures = _G.C_Texture
  if type(textures) ~= "table" or type(textures.GetAtlasInfo) ~= "function" then
    return nil
  end
  for _, name in ipairs(TARGET_ATLASES) do
    local ok, info = pcall(textures.GetAtlasInfo, name)
    if ok and type(info) == "table" and info.file and info.leftTexCoord then
      local l, t = info.leftTexCoord, info.topTexCoord
      local w, h = info.rightTexCoord - l, info.bottomTexCoord - t
      return {
        file = info.file,
        coords = { l + (RING_X - RING_RX) * w, l + (RING_X + RING_RX) * w, t + (RING_Y - RING_RY) * h, t + (RING_Y + RING_RY) * h },
      }
    end
  end
  return nil
end

local function centre(region, frame, size)
  size = math.floor(size) -- whole pixels, as the widget always sized its logo
  region:ClearAllPoints()
  region:SetSize(size, size)
  region:SetPoint("CENTER", frame, "CENTER", 0, 0)
end

local function setGrayed(ring, grayed)
  ring.wmAlwaysDesaturated = grayed or nil
  if ring.SetDesaturated then
    ring:SetDesaturated(grayed)
  end
end

-- A circle mask on the ring, made once per frame; nil where the client has
-- no masks.
local function circleMask(frame, ring)
  if frame.wmRingMask == nil and frame.CreateMaskTexture and ring.AddMaskTexture then
    local mask = frame:CreateMaskTexture()
    mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ring:AddMaskTexture(mask)
    frame.wmRingMask = mask
  end
  return frame.wmRingMask
end

-- parts: { frame, icon, ring }; size: the button's size; plainRatio: the
-- logo's size against the button when there is no ring.
function IconRing.Apply(parts, kind, size, plainRatio)
  local frame, icon, ring = parts.frame, parts.icon, parts.ring
  if not IconRing.RING[kind] then
    icon:SetTexture(IconRing.LOGO)
    centre(icon, frame, size * (plainRatio or 1))
    ring:Hide()
    return
  end

  local look = IconRing.LOOKS[kind]
  local art = kind == "modern" and IconRing.TargetRingArt() or nil
  local mask = art and circleMask(frame, ring)
  if art and mask then
    look = IconRing.LOOKS.modernArt
    ring:SetTexture(art.file)
    ring:SetTexCoord(art.coords[1], art.coords[2], art.coords[3], art.coords[4])
    setGrayed(ring, true)
    centre(mask, frame, size * look.ringScale)
  else
    ring:SetTexture(IconRing.RING[kind])
    ring:SetTexCoord(0, 1, 0, 1)
    setGrayed(ring, false)
  end
  icon:SetTexture(IconRing.RIMLESS_LOGO)
  centre(icon, frame, size * look.logoScale)
  centre(ring, frame, size * look.ringScale)
  ring:Show()
end

ns.IconRing = IconRing
return IconRing
