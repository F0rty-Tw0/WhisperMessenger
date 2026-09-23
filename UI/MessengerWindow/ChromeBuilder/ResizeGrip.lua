local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColorTexture = UIHelpers.applyColorTexture

-- Bottom-right resize grip: three short dotted diagonals in faint neutral
-- white, brighter on hover.
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

function ResizeGrip.Create(factory, frame)
  local grip = factory.CreateFrame("Frame", nil, frame)
  grip:SetSize(GRIP_SIZE, GRIP_SIZE)
  grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
  grip:EnableMouse(true)
  if grip.SetFrameLevel and frame.GetFrameLevel then
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)
  end

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
