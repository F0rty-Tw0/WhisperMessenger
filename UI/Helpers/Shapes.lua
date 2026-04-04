local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Base = ns.UIHelpersBase or require("WhisperMessenger.UI.Helpers.Base")

local Shapes = {}

local CIRCLE_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local ICON_ZOOM = 1.15
local ROUNDED_CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall"

function Shapes.createBorderBox(frame, colorTable, thickness, layer, edges)
  if not frame or type(frame.CreateTexture) ~= "function" then
    return nil
  end

  local edgeThickness = thickness or 1
  local drawLayer = layer or "BORDER"
  local enabled = edges or { top = true, left = true, right = true, bottom = true }
  local border = {}
  if enabled.top ~= false then
    border.top = frame:CreateTexture(nil, drawLayer)
  end
  if enabled.left ~= false then
    border.left = frame:CreateTexture(nil, drawLayer)
  end
  if enabled.right ~= false then
    border.right = frame:CreateTexture(nil, drawLayer)
  end
  if enabled.bottom ~= false then
    border.bottom = frame:CreateTexture(nil, drawLayer)
  end

  if border.top then
    border.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border.top:SetHeight(edgeThickness)
  end

  if border.left then
    border.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    border.left:SetWidth(edgeThickness)
  end

  if border.right then
    border.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border.right:SetWidth(edgeThickness)
  end

  if border.bottom then
    border.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(edgeThickness)
  end

  if colorTable then
    Base.applyBorderBoxColor(border, colorTable)
  end

  return border
end

function Shapes.createCircularIcon(factory, parent, size)
  local frame = factory.CreateFrame("Frame", nil, parent)
  frame:SetSize(size, size)
  if frame.SetClipsChildren then
    frame:SetClipsChildren(true)
  end

  local zoom = math.floor(size * ICON_ZOOM + 0.5)
  local texture = frame:CreateTexture(nil, "ARTWORK")
  texture:SetSize(zoom, zoom)
  texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
  if texture.SetMask then
    texture:SetMask(CIRCLE_MASK)
  end

  return { frame = frame, texture = texture }
end

--- Create a rounded-rectangle background on a frame using fill rects + corner textures.
--- Returns { fills = {textures}, corners = {textures}, setColor = function(colorTable) }
function Shapes.createRoundedBackground(frame, cornerRadius)
  local r = cornerRadius or 8

  local fills = {}
  local corners = {}

  local bgCenter = frame:CreateTexture(nil, "BACKGROUND")
  bgCenter:SetPoint("TOPLEFT", frame, "TOPLEFT", r, -r)
  bgCenter:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -r, r)
  fills[#fills + 1] = bgCenter

  local bgTop = frame:CreateTexture(nil, "BACKGROUND")
  bgTop:SetPoint("TOPLEFT", frame, "TOPLEFT", r, 0)
  bgTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -r, 0)
  bgTop:SetHeight(r)
  fills[#fills + 1] = bgTop

  local bgBottom = frame:CreateTexture(nil, "BACKGROUND")
  bgBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", r, 0)
  bgBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -r, 0)
  bgBottom:SetHeight(r)
  fills[#fills + 1] = bgBottom

  local bgLeft = frame:CreateTexture(nil, "BACKGROUND")
  bgLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -r)
  bgLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, r)
  bgLeft:SetWidth(r)
  fills[#fills + 1] = bgLeft

  local bgRight = frame:CreateTexture(nil, "BACKGROUND")
  bgRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -r)
  bgRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, r)
  bgRight:SetWidth(r)
  fills[#fills + 1] = bgRight

  local function makeCorner(point)
    local c = frame:CreateTexture(nil, "BACKGROUND")
    c:SetSize(r, r)
    c:SetPoint(point, frame, point, 0, 0)
    if c.SetTexture then
      c:SetTexture(ROUNDED_CIRCLE_TEX)
    end
    return c
  end

  local cTL = makeCorner("TOPLEFT")
  local cTR = makeCorner("TOPRIGHT")
  local cBL = makeCorner("BOTTOMLEFT")
  local cBR = makeCorner("BOTTOMRIGHT")

  if cTL.SetTexCoord then
    cTL:SetTexCoord(0, 0.5, 0, 0.5)
    cTR:SetTexCoord(0.5, 1, 0, 0.5)
    cBL:SetTexCoord(0, 0.5, 0.5, 1)
    cBR:SetTexCoord(0.5, 1, 0.5, 1)
  end

  corners[#corners + 1] = cTL
  corners[#corners + 1] = cTR
  corners[#corners + 1] = cBL
  corners[#corners + 1] = cBR

  local function setColor(colorTable)
    local cr, cg, cb, ca = colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1
    local normalizedColor = { cr, cg, cb, ca }
    for _, part in ipairs(fills) do
      Base.applyColorTexture(part, normalizedColor)
    end
    for _, part in ipairs(corners) do
      Base.applyVertexColor(part, normalizedColor)
    end
  end

  return { fills = fills, corners = corners, setColor = setColor }
end

ns.UIHelpersShapes = Shapes

return Shapes
