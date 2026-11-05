local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor

-- The gold ring around the widget and minimap buttons, and the square frame
-- for the square shape. Paints one of four looks: "rim" (ring under the
-- opaque circle, only a rim shows), "ring" (full ring over the button),
-- "square" (square frame) and "none".
local IconBorder = {}

IconBorder.RING_TEXTURE = "InterfaceAddOnsWhisperMessengerMedia\ring_gold.png"
IconBorder.SQUARE_FRAME_TEXTURE = "InterfaceAddOnsWhisperMessengerMedia\frame_gold_square.png"
IconBorder.RIM_SCALE = 1.15
IconBorder.FULL_RING_GLYPH_RATIO = 0.7
-- The ring's hole edge is 0.78 of its radius; the face edge sits mid-band.
IconBorder.FULL_RING_FACE_RATIO = 0.89

local WHITE = { 1, 1, 1, 1 }

function IconBorder.IsOn(getter)
  if getter == nil then
    return true
  end

  return getter() ~= false
end

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

local function paintRing(ring, frame, look, side)
  if look ~= "rim" and look ~= "ring" then
    ring:Hide()
    return
  end

  local isRim = look == "rim"
  local ringSide = isRim and side * IconBorder.RIM_SCALE or side
  ring:SetDrawLayer(isRim and "BACKGROUND" or "OVERLAY", -1)
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

-- parts: { glyph, glyphRatio, squareFrame (true to make one), face (optional) }
function IconBorder.Create(frame, parts)
  local ring = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
  ring:SetTexture(IconBorder.RING_TEXTURE)
  ring:Hide()

  local squareFrame = nil
  if parts.squareFrame == true then
    squareFrame = frame:CreateTexture(nil, "OVERLAY", nil, -1)
    squareFrame:SetTexture(IconBorder.SQUARE_FRAME_TEXTURE)
    squareFrame:SetAllPoints(frame)
    squareFrame:Hide()
  end

  local function paint(look, themed)
    local side = frame:GetWidth()
    local glyphRatio = look == "ring" and IconBorder.FULL_RING_GLYPH_RATIO or parts.glyphRatio
    local glyphSide = math.floor(side * glyphRatio)

    paintRing(ring, frame, look, side)
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
