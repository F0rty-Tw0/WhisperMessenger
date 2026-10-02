local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Hud = ns.Hud or require("WhisperMessenger.UI.Theme.Hud")
local NativeArt = ns.UIHelpersNativeArt or require("WhisperMessenger.UI.Helpers.NativeArt")
local applyColorTexture = UIHelpers.applyColorTexture

-- Bottom-right resize grip: three short dotted diagonals in faint neutral
-- white, brighter on hover. The Native WoW HUD uses the chat frame's size
-- grabber instead.
local ResizeGrip = {}

local GRIP_SIZE = 16
-- { xFromRight, yFromBottom, width, height }
local SHAPES = {
  { 1, 1, 2, 2 },
  { 5, 1, 2, 2 },
  { 1, 5, 2, 2 },
  { 9, 1, 2, 2 },
  { 5, 5, 2, 2 },
  { 1, 9, 2, 2 },
}
local COLOR = { 1, 1, 1, 0.22 }
local HOVER_COLOR = { 1, 1, 1, 0.55 }

local function raise(grip, frame)
  if grip.SetFrameLevel and frame.GetFrameLevel then
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
  end
end

-- Button art does its own hover and pressed states.
local function createNative(factory, frame)
  local L = Theme.LAYOUT
  local grip = factory.CreateFrame("Button", nil, frame)
  grip:SetSize(GRIP_SIZE, GRIP_SIZE)
  grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -L.HUD_INSET_RIGHT, L.HUD_INSET_BOTTOM)
  grip:EnableMouse(true)
  raise(grip, frame)
  grip:SetNormalTexture(NativeArt.SIZE_GRABBER_UP)
  grip:SetPushedTexture(NativeArt.SIZE_GRABBER_DOWN)
  grip:SetHighlightTexture(NativeArt.SIZE_GRABBER_HIGHLIGHT)
  return {
    grip = grip,
    applyTheme = function(_nextTheme) end,
  }
end

function ResizeGrip.Create(factory, frame)
  if Hud.IsOn() then
    return createNative(factory, frame)
  end
  local grip = factory.CreateFrame("Frame", nil, frame)
  grip:SetSize(GRIP_SIZE, GRIP_SIZE)
  grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
  grip:EnableMouse(true)
  raise(grip, frame)

  local parts = {}
  for i, shape in ipairs(SHAPES) do
    local part = grip:CreateTexture(nil, "OVERLAY")
    part:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -shape[1], shape[2])
    part:SetSize(shape[3], shape[4])
    part:Show()
    parts[i] = part
  end

  local function applyVisuals(hovered)
    for _, part in ipairs(parts) do
      applyColorTexture(part, hovered and HOVER_COLOR or COLOR)
    end
  end

  local function isHovered()
    return grip.IsMouseOver and grip:IsMouseOver()
  end

  if grip.SetScript then
    grip:SetScript("OnEnter", function()
      applyVisuals(true)
    end)
    grip:SetScript("OnLeave", function()
      applyVisuals(false)
    end)
  end

  return {
    grip = grip,
    lines = parts,
    applyTheme = function(_nextTheme)
      applyVisuals(isHovered())
    end,
  }
end

ns.MessengerWindowChromeBuilderResizeGrip = ResizeGrip
return ResizeGrip
