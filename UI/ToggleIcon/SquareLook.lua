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

local GLOW_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\soft_glow.png"

local EDGE_COLOR = { 0, 0, 0, 1 }
local HOVER_BRIGHTEN = 0.35 -- how far the hovered accent bubble moves toward white
local GLOW_SCALE = 1.6 -- hover glow size vs the widget

local function setShown(region, shown)
  if shown and region.Show then
    region:Show()
  elseif not shown and region.Hide then
    region:Hide()
  end
end

-- The accent color mixed `amount` of the way to white, for hover.
local function brighten(color, amount)
  local function mix(v)
    return v + (1 - v) * amount
  end
  return { mix(color[1]), mix(color[2]), mix(color[3]), color[4] or 1 }
end

-- The accent back bubble, drawn just under `glyph` and sized with it.
-- apply(desaturated, hovered) shows it under a square theme: brighter while
-- hovered, else in the accent color, or gray while the button is desaturated.
function SquareLook.CreateAccentGlyph(frame, glyph)
  local texture = frame:CreateTexture(nil, "ARTWORK", nil, -1)
  texture:SetAllPoints(glyph)
  texture:SetTexture(SquareLook.ACCENT_GLYPH_TEXTURE)

  local function apply(desaturated, hovered)
    local square = Theme.UsesSquareWidget()
    setShown(texture, square)
    if not square then
      return
    end
    local accent = Theme.COLORS.accent
    if hovered then
      applyVertexColor(texture, brighten(accent, HOVER_BRIGHTEN))
    else
      applyVertexColor(texture, desaturated and Desaturation.DESAT_GREY or accent)
    end
  end

  return { texture = texture, apply = apply }
end

-- Soft accent glow around the icon, shown on hover when there is no square
-- to show the hover.
local function createHoverGlow(frame)
  local glow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
  glow:SetTexture(GLOW_TEXTURE)
  if glow.SetBlendMode then
    glow:SetBlendMode("ADD")
  end
  setShown(glow, false)
  return glow
end

-- parts: { background, border, glyph, roundBackground, roundGlyph,
-- getShowBackground } where the round* fields are the texture paths of the
-- round look; getShowBackground() false leaves just the two bubbles.
function SquareLook.Create(frame, parts)
  local edges = UIHelpers.createBorderBox(frame, EDGE_COLOR, 1, "BORDER") or {}
  UIHelpers.applyBorderBoxColor(edges, EDGE_COLOR)
  local accent = SquareLook.CreateAccentGlyph(frame, parts.glyph)
  local glow = createHoverGlow(frame)
  local hovered = false
  local lastDesaturated = false

  local function squareBackgroundShown()
    return Theme.UsesSquareWidget() and (not parts.getShowBackground or parts.getShowBackground() ~= false)
  end

  local function paintHover()
    accent.apply(lastDesaturated, hovered)
    local glowing = hovered and Theme.UsesSquareWidget() and not squareBackgroundShown()
    setShown(glow, glowing)
    if glowing then
      local size = (frame.GetWidth and frame:GetWidth() or 0) * GLOW_SCALE
      glow:SetSize(size, size)
      applyVertexColor(glow, Theme.COLORS.accent)
    end
  end

  local function apply(desaturated)
    local square = Theme.UsesSquareWidget()
    local squareBackground = squareBackgroundShown()
    parts.background:SetTexture(square and SquareLook.SQUARE_TEXTURE or parts.roundBackground)
    setShown(parts.background, not square or squareBackground)
    parts.glyph:SetTexture(square and SquareLook.GLYPH_TEXTURE or parts.roundGlyph)
    setShown(parts.border, not square)
    for _, edge in pairs(edges) do
      setShown(edge, squareBackground)
    end
    lastDesaturated = desaturated == true
    paintHover()
  end

  -- On a square look only the accent bubble shows the hover (and the glow
  -- when the square is off); the widget's own hover paint is skipped.
  local function setHover(on)
    hovered = on == true
    paintHover()
  end

  return {
    edges = edges,
    accentGlyph = accent.texture,
    hoverGlow = glow,
    apply = apply,
    setHover = setHover,
    isSquare = Theme.UsesSquareWidget,
  }
end

-- Glyph for the round minimap button: the ring-free one under a square
-- theme, so it doesn't stack a second ring inside the button's own.
function SquareLook.MinimapGlyph(roundGlyph)
  return Theme.UsesSquareWidget() and SquareLook.GLYPH_TEXTURE or roundGlyph
end

ns.ToggleIconSquareLook = SquareLook
return SquareLook
