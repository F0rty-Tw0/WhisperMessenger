local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

local CORNER_R = 8

-- Pre-cache the corner texture at load time so it's in memory before any bubble is created
if type(_G.UIParent) == "table" and type(_G.UIParent.CreateTexture) == "function" then
  local preload = _G.UIParent:CreateTexture(nil, "BACKGROUND")
  preload:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
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

  local rounded = UIHelpers.createRoundedBackground(frame, CORNER_R)
  local bgFills = rounded.fills
  local bgCorners = rounded.corners
  local textFS = frame:CreateFontString(nil, "OVERLAY")
  if textFS.SetWordWrap then
    textFS:SetWordWrap(true)
  end
  if textFS.SetNonSpaceWrap then
    textFS:SetNonSpaceWrap(true)
  end

  frame._bgFills = bgFills
  frame._bgCorners = bgCorners
  frame._textFS = textFS

  return bgFills, bgCorners, textFS
end

ns.ChatBubbleBubbleStructure = BubbleStructure
return BubbleStructure
