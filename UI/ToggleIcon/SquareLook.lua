local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Desaturation = ns.ToggleIconDesaturation or require("WhisperMessenger.UI.ToggleIcon.Desaturation")
local PulseGlow = ns.ToggleIconPulseGlow or require("WhisperMessenger.UI.ToggleIcon.PulseGlow")
local SquareEffects = ns.ToggleIconSquareEffects or require("WhisperMessenger.UI.ToggleIcon.SquareEffects")
local ButtonLook = ns.ThemeEllesmereButtonLook or require("WhisperMessenger.UI.Theme.EllesmereButtonLook")
local IconBorder = ns.ToggleIconIconBorder or require("WhisperMessenger.UI.ToggleIcon.IconBorder")
local applyVertexColor = UIHelpers.applyVertexColor

-- The widget's two bubbles (white front glyph over an accent-colored back
-- bubble), shown on every shape, and its square look, chosen by the widget
-- shape setting on any theme: a square drawn like EllesmereUI's action buttons
-- in place of the circle.
local SquareLook = {}

SquareLook.SQUARE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
SquareLook.GLYPH_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_front.png"
SquareLook.ACCENT_GLYPH_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_back.png"

-- Halo around the two bubbles' outline (clear inside them), for the glyph
-- drawn without the background and the square look's pulse. Its canvas is
-- BUBBLE_GLOW_SCALE times the glyph's, glyph centred, so the halo has room
-- past the glyph's edges.
SquareLook.BUBBLE_GLOW_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_glow.png"
SquareLook.BUBBLE_GLOW_SCALE = 1.5

-- Thin outline around both bubbles (filling the gap between them), so the
-- gray back bubble still reads over bright ground without the background.
SquareLook.OUTLINE_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\chat_glyph_outline.png"

local OUTLINE_COLOR = { 0, 0, 0, 0.85 }

local function setShown(region, shown)
  if shown and region.Show then
    region:Show()
  elseif not shown and region.Hide then
    region:Hide()
  end
end

-- The accent back bubble, drawn just under `glyph` and sized with it.
-- apply(desaturated, hovered) shows it in the accent color, or gray while the
-- button is desaturated and not hovered: DESAT_GREY when isSquare() is true,
-- else DESAT_BACK. isSquare is optional.
function SquareLook.CreateAccentGlyph(frame, glyph, isSquare)
  local texture = frame:CreateTexture(nil, "ARTWORK", nil, -1)
  texture:SetAllPoints(glyph)
  texture:SetTexture(SquareLook.ACCENT_GLYPH_TEXTURE)

  local function apply(desaturated, hovered)
    setShown(texture, true)
    local grey = isSquare and isSquare() and Desaturation.DESAT_GREY or Desaturation.DESAT_BACK
    local color = desaturated and not hovered and grey or Theme.COLORS.accent
    applyVertexColor(texture, color)
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

-- Accent halo around the bubbles, shown on hover when there is no background
-- to show the hover.
local function createHoverGlow(frame)
  local glow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
  if glow.SetBlendMode then
    glow:SetBlendMode("ADD")
  end
  setShown(glow, false)
  return glow
end

-- parts: { background, glyph, roundBackground, getShowBackground, getWidgetShape,
-- getShowBorder, getBorderThemed, border, pulse } where roundBackground is the
-- texture path of the round look's circle; getShowBackground() false leaves
-- just the two bubbles (inside the full ring on the circle); getWidgetShape()
-- returns "square" for the square look, and a missing getter or any other
-- value means the circle. border is an IconBorder painted on every apply;
-- getShowBorder() false takes it off, getBorderThemed() false keeps it gold.
-- A missing getter means on.
-- The square is drawn like EllesmereUI's action buttons (EllesmereButtonLook):
-- slot background, border, and their hover and pushed effects.
-- The unread pulse (a PulseGlow) glows around the bubbles on the square look.
function SquareLook.Create(frame, parts)
  local function isSquare()
    return parts.getWidgetShape ~= nil and parts.getWidgetShape() == "square"
  end

  local border = SquareEffects.Create(frame, "BORDER", 0)
  local hoverEffect = SquareEffects.Create(frame, "OVERLAY", 1)
  local pushEffect = SquareEffects.Create(frame, "OVERLAY", 2)
  local accent = SquareLook.CreateAccentGlyph(frame, parts.glyph, isSquare)
  local outline = frame:CreateTexture(nil, "ARTWORK", nil, -2)
  outline:SetAllPoints(parts.glyph)
  outline:SetTexture(SquareLook.OUTLINE_TEXTURE)
  applyVertexColor(outline, OUTLINE_COLOR)
  local glow = createHoverGlow(frame)
  local hovered = false
  local pushed = false
  local lastDesaturated = false
  local look = ButtonLook.Read()

  local function backgroundShown()
    return IconBorder.IsOn(parts.getShowBackground)
  end

  local function squareBackgroundShown()
    return isSquare() and backgroundShown()
  end

  local function bubblesOnly()
    return not backgroundShown()
  end

  -- The square's slot fill, border and effects; repainted after a hover too,
  -- since the widget's own hover code repaints the background.
  local function paintSquare()
    local squareBackground = squareBackgroundShown()
    if squareBackground then
      applyVertexColor(parts.background, look.bg)
    end
    border.show(squareBackground)
    hoverEffect.show(squareBackground and hovered)
    pushEffect.show(squareBackground and pushed)
  end

  local function paintHover()
    accent.apply(lastDesaturated, hovered)
    local glowing = hovered and bubblesOnly()
    setShown(glow, glowing)
    if glowing then
      fitBubbleGlow(glow, parts.glyph)
      applyVertexColor(glow, Theme.COLORS.accent)
    end
    paintSquare()
  end

  -- The pulse's round art is made for the round button; on the square look
  -- it glows around the bubbles' outline instead, square shown or not.
  local function shapePulse()
    local pulse = parts.pulse and parts.pulse.glowTexture
    if not pulse then
      return
    end
    if isSquare() then
      fitBubbleGlow(pulse, parts.glyph)
    else
      pulse:SetTexture(PulseGlow.TEXTURE)
      pulse:ClearAllPoints()
      pulse:SetAllPoints(parts.pulse.glowFrame)
    end
  end

  local function apply(desaturated)
    local square = isSquare()
    -- First: the glows below are sized from the glyph the border sizes.
    parts.border.paint(IconBorder.LookFor(square, backgroundShown(), IconBorder.IsOn(parts.getShowBorder)), IconBorder.IsOn(parts.getBorderThemed))
    look = ButtonLook.Read()
    border.paint({ kind = "edge", color = look.border, px = look.borderPx })
    hoverEffect.paint(look.hover, look.borderPx)
    pushEffect.paint(look.push, look.borderPx)
    parts.background:SetTexture(square and SquareLook.SQUARE_TEXTURE or parts.roundBackground)
    setShown(parts.background, backgroundShown())
    setShown(outline, bubblesOnly())
    lastDesaturated = desaturated == true
    paintHover()
    shapePulse()
  end

  -- The back bubble returns to the accent on hover. On a square look that
  -- comes with EllesmereUI's hover effect on the square, or the glow when the
  -- background is off on either shape; the square repaints its own fill over
  -- the widget's.
  local function setHover(on)
    hovered = on == true
    if not hovered then
      pushed = false
    end
    paintHover()
  end

  -- EllesmereUI's pushed effect while the mouse is held on the square.
  local function setPushed(on)
    pushed = on == true
    paintSquare()
  end

  return {
    edges = border.edges,
    hoverEffect = hoverEffect.fill,
    pushEffect = pushEffect.fill,
    accentGlyph = accent.texture,
    outline = outline,
    hoverGlow = glow,
    apply = apply,
    setHover = setHover,
    setPushed = setPushed,
  }
end

ns.ToggleIconSquareLook = SquareLook
return SquareLook
