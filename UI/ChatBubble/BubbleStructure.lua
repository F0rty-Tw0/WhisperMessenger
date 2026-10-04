local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Hyperlinks = ns.UIHyperlinks or require("WhisperMessenger.UI.Hyperlinks")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local PickerPopup = ns.PickerPopup or require("WhisperMessenger.UI.Shared.PickerPopup")

local CORNER_R = 8

-- Pre-cache the corner texture at load time so it's in memory before any bubble is created
if type(_G.UIParent) == "table" and type(_G.UIParent.CreateTexture) == "function" then
  local preload = _G.UIParent:CreateTexture(nil, "BACKGROUND")
  preload:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall")
  preload:SetAlpha(0)
  preload:SetSize(1, 1)
end

local BubbleStructure = {}

function BubbleStructure.measureTextHeight(fontString, text, maxWidth)
  fontString:SetWidth(maxWidth)
  fontString:SetText(text or "")
  return fontString:GetStringHeight() or 14
end

-- Native WoW HUD bubble background: a tooltip-bordered child frame, so it
-- hides with the bubble. Filled by BubbleFrame's applyBubbleColor.
local function createNativeBackdrop(factory, frame)
  local backdrop = PickerPopup.CreateTooltipFrame(factory, frame)
  backdrop:SetAllPoints(frame)
  return backdrop
end

-- Shows the bubble's native backdrop one frame level below the bubble, so the
-- bubble's text and child widgets draw over it. Re-applied on every render in
-- case the window was re-levelled since. No-op without a backdrop.
function BubbleStructure.showNativeBackdrop(frame)
  local backdrop = frame._nativeBackdrop
  if not backdrop then
    return
  end
  if type(backdrop.SetFrameLevel) == "function" and type(frame.GetFrameLevel) == "function" then
    backdrop:SetFrameLevel(math.max(frame:GetFrameLevel() - 1, 0))
  end
  if backdrop.Show then
    backdrop:Show()
  end
end

-- Create the structural frame elements (textures, corners, font string).
-- Called once per frame; results are cached on frame._bgFills, _bgCorners, _textFS
-- (and frame._nativeBackdrop under the Native WoW HUD, which has no rounded
-- fill). `factory` builds the backdrop and must not be a frame pool.
function BubbleStructure.createStructure(frame, factory)
  if frame.EnableMouse then
    frame:EnableMouse(true)
  end
  if frame.SetHyperlinksEnabled then
    frame:SetHyperlinksEnabled(true)
  end
  if frame.SetScript then
    frame:SetScript("OnHyperlinkEnter", function(self, link, _text)
      Hyperlinks.HandleEnter(self, link)
    end)
    frame:SetScript("OnHyperlinkLeave", function(self)
      Hyperlinks.HandleLeave()
    end)
    frame:SetScript("OnHyperlinkClick", function(self, link, text, button)
      Hyperlinks.HandleClick(link, text, button, self)
    end)
  end

  local bgFills, bgCorners
  if Hud.IsOn() and factory then
    frame._nativeBackdrop = createNativeBackdrop(factory, frame)
    bgFills, bgCorners = {}, {}
  else
    local rounded = UIHelpers.createRoundedBackground(frame, CORNER_R)
    bgFills = rounded.fills
    bgCorners = rounded.corners
  end
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
