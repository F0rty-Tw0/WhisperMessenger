local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor

-- The toggle icon's round face: circle background, ring border and the
-- chat glyph, plus the theme colours each one is painted with.
local IconArt = {}

local ADDON_ICON_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\icon.png"
local CHAT_ICON_RATIO = 0.9 -- chat icon scale factor vs ICON_SIZE

-- Circular background: use the circle texture directly, tinted to desired color
local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local RING_TEX = "Interface\\COMMON\\RingBorder"

IconArt.ADDON_ICON_TEXTURE = ADDON_ICON_TEXTURE
IconArt.CIRCLE_TEX = CIRCLE_TEX

local function resolveBgColor()
  return Theme.COLORS.toggle_icon_bg
end
local function resolveRingColor()
  local c = Theme.COLORS.toggle_icon_ring
  if c then
    return c
  end
  local a = Theme.COLORS.accent or { 1, 1, 1, 1 }
  return { a[1], a[2], a[3], 0.3 }
end
local function resolveGlyphColor()
  return Theme.COLORS.toggle_icon_glyph or Theme.COLORS.text_primary
end

IconArt.resolveBgColor = resolveBgColor
IconArt.resolveRingColor = resolveRingColor
IconArt.resolveGlyphColor = resolveGlyphColor

function IconArt.Create(frame, iconSize)
  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:SetTexture(CIRCLE_TEX)
  applyVertexColor(background, resolveBgColor())

  -- Circular border ring: the generic `COMMON\RingBorder` hoop, which
  -- paints cleanly with any vertex-color tint from the preset palette.
  local border = frame:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
  border:SetTexture(RING_TEX)
  applyVertexColor(border, resolveRingColor())

  -- Chat icon (speech bubble) instead of text label
  local chatIcon = frame:CreateTexture(nil, "ARTWORK")
  chatIcon:SetSize(iconSize * CHAT_ICON_RATIO, iconSize * CHAT_ICON_RATIO)
  chatIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)
  chatIcon:SetTexture(ADDON_ICON_TEXTURE)
  applyVertexColor(chatIcon, resolveGlyphColor())

  -- Resizes the glyph and re-anchors the ring after the frame took newSize.
  local function applySize(newSize)
    chatIcon:SetSize(math.floor(newSize * CHAT_ICON_RATIO), math.floor(newSize * CHAT_ICON_RATIO))
    if border.SetPoint and border.ClearAllPoints then
      border:ClearAllPoints()
      border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
      border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    end
  end

  return {
    background = background,
    border = border,
    chatIcon = chatIcon,
    applySize = applySize,
  }
end

ns.ToggleIconIconArt = IconArt
return IconArt
