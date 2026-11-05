local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor

-- The ring around the widget and minimap buttons, and the square frame for
-- the square shape, in the theme accent or their gold art (the minimap always
-- paints gold). Paints one of four looks: "rim" (ring under the opaque circle,
-- only a rim shows), "ring" (full ring over the button, sized by ringScale),
-- "square" (square frame) and "none".
local IconBorder = {}

IconBorder.RING_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\ring_gold.png"
IconBorder.SQUARE_FRAME_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\frame_gold_square.png"
IconBorder.RIM_SCALE = 1.15
IconBorder.FULL_RING_GLYPH_RATIO = 0.7
-- The ring's hole edge is 0.78 of its radius; the face edge sits mid-band.
IconBorder.FULL_RING_FACE_RATIO = 0.89

local WHITE = { 1, 1, 1, 1 }
-- Draw sublevel of the ring and the square frame, under anything else on their layer.
local BORDER_SUBLEVEL = -1

function IconBorder.LookFor(square, background, border)
  if not border then
    return "none"
  end
  if square then
    return "square"
  end
  if background then
    return "rim"
  end

  return "ring"
end

local function tint(texture, themed)
  texture:SetDesaturated(themed)
  applyVertexColor(texture, themed and Theme.COLORS.accent or WHITE)
end

local function paintRing(ring, frame, look, side, ringScale)
  if look ~= "rim" and look ~= "ring" then
    ring:Hide()

    return
  end

  local isRim = look == "rim"
  local ringSide = side * (isRim and IconBorder.RIM_SCALE or ringScale)
  ring:SetDrawLayer(isRim and "BACKGROUND" or "OVERLAY", BORDER_SUBLEVEL)
  ring:SetSize(ringSide, ringSide)
  ring:ClearAllPoints()
  ring:SetPoint("CENTER", frame, "CENTER", 0, 0)
  ring:Show()
end

local function paintFace(face, frame, look, side)
  face:ClearAllPoints()
  if look ~= "ring" then
    face:SetAllPoints(frame)

    return
  end

  local faceSide = side * IconBorder.FULL_RING_FACE_RATIO
  face:SetSize(faceSide, faceSide)
  face:SetPoint("CENTER", frame, "CENTER", 0, 0)
end

-- parts: { glyph, glyphRatio, withSquareFrame (true to make one), face (optional),
-- ringScale (optional, default 1): the "ring" look's size and bubbles relative to
-- the button. The widget passes RIM_SCALE so its outer edge matches the "rim";
-- the minimap keeps 1 for its fixed footprint. }
function IconBorder.Create(frame, parts)
  local ringScale = parts.ringScale or 1
  local ring = frame:CreateTexture(nil, "BACKGROUND", nil, BORDER_SUBLEVEL)
  ring:SetTexture(IconBorder.RING_TEXTURE)
  ring:Hide()

  local squareFrame = nil
  if parts.withSquareFrame == true then
    squareFrame = frame:CreateTexture(nil, "OVERLAY", nil, BORDER_SUBLEVEL)
    squareFrame:SetTexture(IconBorder.SQUARE_FRAME_TEXTURE)
    squareFrame:SetAllPoints(frame)
    squareFrame:Hide()
  end

  local function paint(look, themed)
    local side = frame:GetWidth()
    local glyphRatio = look == "ring" and IconBorder.FULL_RING_GLYPH_RATIO * ringScale or parts.glyphRatio
    local glyphSide = math.floor(side * glyphRatio)

    paintRing(ring, frame, look, side, ringScale)
    tint(ring, themed)
    if squareFrame then
      squareFrame:SetShown(look == "square")
      tint(squareFrame, themed)
    end
    parts.glyph:SetSize(glyphSide, glyphSide)
    if parts.face then
      paintFace(parts.face, frame, look, side)
    end
  end

  return { ring = ring, squareFrame = squareFrame, paint = paint }
end

ns.ToggleIconIconBorder = IconBorder

return IconBorder
