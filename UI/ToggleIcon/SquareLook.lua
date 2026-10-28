local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Desaturation = ns.ToggleIconDesaturation or require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local applyVertexColor = UIHelpers.applyVertexColor

-- The widget's square look for themes that want one (EllesmereUI): a flat
-- fill, a 1px black edge like EllesmereUI's buttons, and the ring-free
-- glyph (white front bubble over an accent-colored back bubble) instead of
-- the round art. Swaps the widget's own textures, so its hover, desaturate
-- and pulse paint keep working unchanged.
local SquareLook = {}

SquareLook.SQUARE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
SquareLook.GLYPH_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_front.png"
SquareLook.ACCENT_GLYPH_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_back.png"

local EDGE_COLOR = { 0, 0, 0, 1 }

local function setShown(region, shown)
  if shown and region.Show then
    region:Show()
  elseif not shown and region.Hide then
    region:Hide()
  end
end

-- The accent back bubble, drawn just under `glyph` and sized with it.
-- apply(desaturated) shows it under a square theme, in the accent color, or
-- gray while the button is desaturated.
function SquareLook.CreateAccentGlyph(frame, glyph)
  local texture = frame:CreateTexture(nil, "ARTWORK", nil, -1)
  texture:SetAllPoints(glyph)
  texture:SetTexture(SquareLook.ACCENT_GLYPH_TEXTURE)

  local function apply(desaturated)
    local square = Theme.UsesSquareWidget()
    setShown(texture, square)
    if square then
      applyVertexColor(texture, desaturated and Desaturation.DESAT_GREY or Theme.COLORS.accent)
    end
  end

  return { texture = texture, apply = apply }
end

-- parts: { background, border, glyph, roundBackground, roundGlyph } where
-- the round* fields are the texture paths of the round look.
function SquareLook.Create(frame, parts)
  local edges = UIHelpers.createBorderBox(frame, EDGE_COLOR, 1, "BORDER") or {}
  UIHelpers.applyBorderBoxColor(edges, EDGE_COLOR)
  local accent = SquareLook.CreateAccentGlyph(frame, parts.glyph)

  local function apply(desaturated)
    local square = Theme.UsesSquareWidget()
    parts.background:SetTexture(square and SquareLook.SQUARE_TEXTURE or parts.roundBackground)
    parts.glyph:SetTexture(square and SquareLook.GLYPH_TEXTURE or parts.roundGlyph)
    setShown(parts.border, not square)
    for _, edge in pairs(edges) do
      setShown(edge, square)
    end
    accent.apply(desaturated)
  end

  return { edges = edges, accentGlyph = accent.texture, apply = apply }
end

-- Glyph for the round minimap button: the ring-free one under a square
-- theme, so it doesn't stack a second ring inside the button's own.
function SquareLook.MinimapGlyph(roundGlyph)
  return Theme.UsesSquareWidget() and SquareLook.GLYPH_TEXTURE or roundGlyph
end

ns.ToggleIconSquareLook = SquareLook
return SquareLook
