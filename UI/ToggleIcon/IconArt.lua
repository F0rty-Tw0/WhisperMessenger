local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local SquareLook = ns.ToggleIconSquareLook or require("WhisperMessenger.UI.ToggleIcon.SquareLook")
local applyVertexColor = UIHelpers.applyVertexColor

-- The toggle icon's round face: circle and chat glyph, plus the theme
-- colours each one is painted with.
local IconArt = {}

local GLYPH_RATIO = 0.9 -- chat icon scale factor vs ICON_SIZE
local HOVER_ACCENT_MIX = 0.15 -- share of the accent blended into the circle on hover

-- Circular background: use the circle texture directly, tinted to desired color
local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

IconArt.CIRCLE_TEX = CIRCLE_TEX
IconArt.GLYPH_RATIO = GLYPH_RATIO

local function resolveBgColor()
  return Theme.COLORS.toggle_icon_bg
end
local function resolveGlyphColor()
  return Theme.COLORS.toggle_icon_glyph or Theme.COLORS.text_primary
end

-- The circle's hover fill: the bg nudged toward the accent, alpha kept.
local function resolveHoverBgColor()
  local bg = resolveBgColor()
  local accent = Theme.COLORS.accent
  if not accent then
    return bg
  end
  local keep = 1 - HOVER_ACCENT_MIX
  return {
    bg[1] * keep + accent[1] * HOVER_ACCENT_MIX,
    bg[2] * keep + accent[2] * HOVER_ACCENT_MIX,
    bg[3] * keep + accent[3] * HOVER_ACCENT_MIX,
    bg[4],
  }
end

IconArt.ResolveBgColor = resolveBgColor
IconArt.ResolveHoverBgColor = resolveHoverBgColor
IconArt.ResolveGlyphColor = resolveGlyphColor

function IconArt.Create(frame, iconSize)
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:SetTexture(CIRCLE_TEX)
  applyVertexColor(background, resolveBgColor())

  -- Chat icon (speech bubble) instead of text label
  local chatIcon = frame:CreateTexture(nil, "ARTWORK")
  chatIcon:SetSize(iconSize * GLYPH_RATIO, iconSize * GLYPH_RATIO)
  chatIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)
  chatIcon:SetTexture(SquareLook.GLYPH_TEXTURE)
  applyVertexColor(chatIcon, resolveGlyphColor())

  -- Resizes the glyph after the frame took newSize.
  local function applySize(newSize)
    chatIcon:SetSize(math.floor(newSize * GLYPH_RATIO), math.floor(newSize * GLYPH_RATIO))
  end

  return {
    background = background,
    chatIcon = chatIcon,
    applySize = applySize,
  }
end

-- Paints the face from IconArt.Create in the theme's colors; hovered lifts the circle.
function IconArt.PaintFace(art, hovered)
  applyVertexColor(art.background, hovered and resolveHoverBgColor() or resolveBgColor())
  applyVertexColor(art.chatIcon, resolveGlyphColor())
end

ns.ToggleIconIconArt = IconArt
return IconArt
