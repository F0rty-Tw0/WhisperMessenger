local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Soft drop shadow around the custom-chrome window. Eight pieces
-- of Media/shadow.png (a 64px texture whose outer 16px band is the blurred
-- falloff) are created once on the window's lowest background sublayer and
-- sit fully outside the window edge. Never used on rows or bubbles.
local WindowShadow = {}

local SHADOW_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\shadow.png"
local OUTSET = 14
local ALPHA = 0.5
local LO, HI = 0.25, 0.75 -- texcoord edges of the 16px band in a 64px texture

-- { anchors = { {point, relativePoint}, ... }, width?, height?, texcoords }
local PIECES = {
  { anchors = { { "BOTTOMRIGHT", "TOPLEFT" } }, width = OUTSET, height = OUTSET, tex = { 0, LO, 0, LO } },
  { anchors = { { "BOTTOMLEFT", "TOPRIGHT" } }, width = OUTSET, height = OUTSET, tex = { HI, 1, 0, LO } },
  { anchors = { { "TOPRIGHT", "BOTTOMLEFT" } }, width = OUTSET, height = OUTSET, tex = { 0, LO, HI, 1 } },
  { anchors = { { "TOPLEFT", "BOTTOMRIGHT" } }, width = OUTSET, height = OUTSET, tex = { HI, 1, HI, 1 } },
  { anchors = { { "BOTTOMLEFT", "TOPLEFT" }, { "BOTTOMRIGHT", "TOPRIGHT" } }, height = OUTSET, tex = { LO, HI, 0, LO } },
  { anchors = { { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }, height = OUTSET, tex = { LO, HI, HI, 1 } },
  { anchors = { { "TOPRIGHT", "TOPLEFT" }, { "BOTTOMRIGHT", "BOTTOMLEFT" } }, width = OUTSET, tex = { 0, LO, LO, HI } },
  { anchors = { { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" } }, width = OUTSET, tex = { HI, 1, LO, HI } },
}

function WindowShadow.Create(frame)
  local parts = {}
  for i, piece in ipairs(PIECES) do
    local part = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    part:SetTexture(SHADOW_TEXTURE)
    part:SetTexCoord(piece.tex[1], piece.tex[2], piece.tex[3], piece.tex[4])
    for _, anchor in ipairs(piece.anchors) do
      part:SetPoint(anchor[1], frame, anchor[2], 0, 0)
    end
    if piece.width then
      part:SetWidth(piece.width)
    end
    if piece.height then
      part:SetHeight(piece.height)
    end
    part:SetVertexColor(1, 1, 1, ALPHA)
    part:Show()
    parts[i] = part
  end

  return { parts = parts }
end

ns.MessengerWindowChromeBuilderWindowShadow = WindowShadow
return WindowShadow
