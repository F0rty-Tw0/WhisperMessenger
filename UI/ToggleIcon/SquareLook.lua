local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Desaturation = ns.ToggleIconDesaturation or require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local PulseGlow = ns.ToggleIconPulseGlow or require("WhisperMessenger.UI.ToggleIcon.PulseGlow")
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

-- Halo around the two bubbles' outline (clear inside them), for the glyph
-- drawn without the square. Its canvas is BUBBLE_GLOW_SCALE times the
-- glyph's, glyph centred, so the halo has room past the glyph's edges.
SquareLook.BUBBLE_GLOW_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_glow.png"
SquareLook.BUBBLE_GLOW_SCALE = 1.5

-- Thin outline around both bubbles (filling the gap between them), so the
-- gray back bubble still reads over bright ground without the square.
SquareLook.OUTLINE_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_outline.png"

local EDGE_COLOR = { 0, 0, 0, 1 }
local OUTLINE_COLOR = { 0, 0, 0, 0.85 }

local function setShown(region, shown)
  if shown and region.Show then
    region:Show()
  elseif not shown and region.Hide then
    region:Hide()
  end
end

-- The accent back bubble, drawn just under `glyph` and sized with it.
-- apply(desaturated, hovered) shows it under a square theme in the accent
-- color, or gray while the button is desaturated and not hovered.
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
    local grey = desaturated and not hovered
    applyVertexColor(texture, grey and Desaturation.DESAT_GREY or Theme.COLORS.accent)
  end

  return { texture = texture, apply = apply }
end

-- Puts the bubble halo on `texture`, centred on `glyph` and sized to it.
local function fitBubbleGlow(texture, glyph)
  local size = (glyph.GetWidth and glyph:GetWidth() or 0) * SquareLook.BUBBLE_GLOW_SCALE
  texture:SetTexture(SquareLook.BUBBLE_GLOW_TEXTURE)
  texture:ClearAllPoints()
  texture:SetPoint("CENTER", glyph, "CENTER", 0, 0)
  texture:SetSize(size, size)
end

-- Accent halo around the bubbles, shown on hover when there is no square
-- to show the hover.
local function createHoverGlow(frame)
  local glow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  if glow.SetBlendMode then
    glow:SetBlendMode("ADD")
  end
  setShown(glow, false)
  return glow
end

-- parts: { background, border, glyph, roundBackground, roundGlyph,
-- getShowBackground, pulse } where the round* fields are the texture paths
-- of the round look; getShowBackground() false leaves just the two bubbles.
-- The unread pulse (a PulseGlow) glows around the bubbles on the square look.
function SquareLook.Create(frame, parts)
  local edges = UIHelpers.createBorderBox(frame, EDGE_COLOR, 1, "BORDER") or {}
  UIHelpers.applyBorderBoxColor(edges, EDGE_COLOR)
  local accent = SquareLook.CreateAccentGlyph(frame, parts.glyph)
  local outline = frame:CreateTexture(nil, "ARTWORK", nil, -2)
  outline:SetAllPoints(parts.glyph)
  outline:SetTexture(SquareLook.OUTLINE_TEXTURE)
  applyVertexColor(outline, OUTLINE_COLOR)
  local glow = createHoverGlow(frame)
  local hovered = false
  local lastDesaturated = false

  local function squareBackgroundShown()
    return Theme.UsesSquareWidget() and (not parts.getShowBackground or parts.getShowBackground() ~= false)
  end

  local function bubblesOnly()
    return Theme.UsesSquareWidget() and not squareBackgroundShown()
  end

  local function paintHover()
    accent.apply(lastDesaturated, hovered)
    local glowing = hovered and bubblesOnly()
    setShown(glow, glowing)
    if glowing then
      fitBubbleGlow(glow, parts.glyph)
      applyVertexColor(glow, Theme.COLORS.accent)
    end
  end

  -- The pulse's round art is made for the round button; on the square look
  -- it glows around the bubbles' outline instead, square shown or not.
  local function shapePulse()
    local pulse = parts.pulse and parts.pulse.glowTexture
    if not pulse then
      return
    end
    if Theme.UsesSquareWidget() then
      fitBubbleGlow(pulse, parts.glyph)
    else
      pulse:SetTexture(PulseGlow.TEXTURE)
      pulse:ClearAllPoints()
      pulse:SetAllPoints(parts.pulse.glowFrame)
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
    setShown(outline, bubblesOnly())
    lastDesaturated = desaturated == true
    paintHover()
    shapePulse()
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
    outline = outline,
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
