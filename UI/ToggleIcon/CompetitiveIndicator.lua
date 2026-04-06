local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor

local CompetitiveIndicator = {}

local INDICATOR_SIZE = 16
local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local LOCK_TEX = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"
local LOCK_COLOR = { 1, 0.82, 0, 1 }
local BG_COLOR = { 0.15, 0.15, 0.15, 0.9 }

function CompetitiveIndicator.Create(factory, parentFrame)
  local frame = factory.CreateFrame("Frame", nil, parentFrame)
  frame:SetSize(INDICATOR_SIZE, INDICATOR_SIZE)
  frame:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", -4, -4)

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:SetTexture(CIRCLE_TEX)
  applyVertexColor(background, BG_COLOR)

  local icon = frame:CreateTexture(nil, "ARTWORK")
  icon:SetSize(INDICATOR_SIZE * 0.7, INDICATOR_SIZE * 0.7)
  icon:SetPoint("CENTER", frame, "CENTER", 0, 0)
  icon:SetTexture(LOCK_TEX)
  applyVertexColor(icon, LOCK_COLOR)

  if frame.Hide then
    frame:Hide()
  end

  local function setActive(active)
    if active then
      if frame.Show then
        frame:Show()
      end
    else
      if frame.Hide then
        frame:Hide()
      end
    end
  end

  return {
    frame = frame,
    background = background,
    icon = icon,
    setActive = setActive,
  }
end

ns.CompetitiveIndicator = CompetitiveIndicator
return CompetitiveIndicator
