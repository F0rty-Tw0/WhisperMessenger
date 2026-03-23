local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local CORNER_R = 8
local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall"

-- Pre-cache the corner texture at load time so it's in memory before any bubble is created
if type(_G.UIParent) == "table" and type(_G.UIParent.CreateTexture) == "function" then
  local preload = _G.UIParent:CreateTexture(nil, "BACKGROUND")
  preload:SetTexture(CIRCLE_TEX)
  preload:SetAlpha(0)
  preload:SetSize(1, 1)
end

local BubbleStructure = {}

BubbleStructure.CORNER_R = CORNER_R

function BubbleStructure.measureTextHeight(fontString, text, maxWidth)
  fontString:SetWidth(maxWidth)
  fontString:SetText(text or "")
  return fontString:GetStringHeight() or 14
end

-- Create the structural frame elements (textures, corners, font string).
-- Called once per frame; results are cached on frame._bgFills, _bgCorners, _textFS.
function BubbleStructure.createStructure(frame)
  if frame.EnableMouse then
    frame:EnableMouse(true)
  end
  if frame.SetHyperlinksEnabled then
    frame:SetHyperlinksEnabled(true)
  end
  if frame.SetScript then
    frame:SetScript("OnHyperlinkEnter", function(self, link, _text)
      if type(_G.GameTooltip) == "table" and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        _G.GameTooltip:SetHyperlink(link)
        _G.GameTooltip:Show()
      end
    end)
    frame:SetScript("OnHyperlinkLeave", function(self)
      if type(_G.GameTooltip) == "table" and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)
    frame:SetScript("OnHyperlinkClick", function(self, link, text, button)
      if type(_G.SetItemRef) == "function" then
        _G.SetItemRef(link, text, button, self)
      end
    end)
  end

  local bgCenter = frame:CreateTexture(nil, "BACKGROUND")
  bgCenter:SetPoint("TOPLEFT", frame, "TOPLEFT", CORNER_R, -CORNER_R)
  bgCenter:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CORNER_R, CORNER_R)

  local bgTop = frame:CreateTexture(nil, "BACKGROUND")
  bgTop:SetPoint("TOPLEFT", frame, "TOPLEFT", CORNER_R, 0)
  bgTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CORNER_R, 0)
  bgTop:SetHeight(CORNER_R)

  local bgBottom = frame:CreateTexture(nil, "BACKGROUND")
  bgBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", CORNER_R, 0)
  bgBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CORNER_R, 0)
  bgBottom:SetHeight(CORNER_R)

  local bgLeft = frame:CreateTexture(nil, "BACKGROUND")
  bgLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -CORNER_R)
  bgLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, CORNER_R)
  bgLeft:SetWidth(CORNER_R)

  local bgRight = frame:CreateTexture(nil, "BACKGROUND")
  bgRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -CORNER_R)
  bgRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, CORNER_R)
  bgRight:SetWidth(CORNER_R)

  local function makeCorner(point)
    local c = frame:CreateTexture(nil, "BACKGROUND")
    c:SetSize(CORNER_R, CORNER_R)
    c:SetPoint(point, frame, point, 0, 0)
    if c.SetTexture then
      c:SetTexture(CIRCLE_TEX)
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

  local bgFills = { bgCenter, bgTop, bgBottom, bgLeft, bgRight }
  local bgCorners = { cTL, cTR, cBL, cBR }
  local textFS = frame:CreateFontString(nil, "OVERLAY")

  frame._bgFills = bgFills
  frame._bgCorners = bgCorners
  frame._textFS = textFS

  return bgFills, bgCorners, textFS
end

ns.ChatBubbleBubbleStructure = BubbleStructure
return BubbleStructure
