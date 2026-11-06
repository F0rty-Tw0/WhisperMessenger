local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

-- Where the phone window opens and where the floating button rides on it.
-- The Retail HUD has a round portrait for the button to become; every other
-- look has the button hang off the window's top-left corner.
local PhoneDock = {}

local function portraitOf(frame)
  local container = frame.PortraitContainer
  return container and (container.portrait or container) or nil
end

-- Portrait centre relative to the window's top-left corner; nil until the
-- client has laid the window out.
local function portraitOffset(frame, portrait)
  local left = frame.GetLeft and frame:GetLeft()
  local top = frame.GetTop and frame:GetTop()
  local x, y = nil, nil
  if portrait.GetCenter then
    x, y = portrait:GetCenter()
  end
  if not (left and top and x and y) then
    return nil
  end
  return x - left, y - top
end

local function iconHalfWidth(iconFrame)
  return (iconFrame:GetWidth() or 0) / 2
end

local function spotOffset(frame, iconFrame)
  local portrait = portraitOf(frame)
  local offsetX, offsetY = nil, nil
  if portrait then
    offsetX, offsetY = portraitOffset(frame, portrait)
  end
  if offsetX then
    return offsetX, offsetY
  end
  local inset = iconHalfWidth(iconFrame) - Theme.LAYOUT.PHONE_CORNER_OVERLAP
  return -inset, inset
end

-- Places the window so its button spot lands on the button. The window stays
-- clamped to the screen, so near an edge the button travels further to reach it.
function PhoneDock.Place(frame, iconFrame)
  if iconFrame == nil or not iconFrame.GetCenter then
    return
  end
  local iconX, iconY = iconFrame:GetCenter()
  if iconX == nil then
    return
  end
  local ratio = iconFrame:GetEffectiveScale() / frame:GetEffectiveScale()
  local offsetX, offsetY = spotOffset(frame, iconFrame)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent() or _G.UIParent, "BOTTOMLEFT", iconX * ratio - offsetX, iconY * ratio - offsetY)
end

-- What IconRide needs to carry the button onto this window.
function PhoneDock.RideTarget(frame, iconFrame)
  local level = Theme.LAYOUT.PHONE_RIDE_FRAME_LEVEL
  local portrait = portraitOf(frame)
  local iconWidth = iconFrame:GetWidth() or 0
  local portraitWidth = portrait and portrait:GetWidth() or 0
  if portraitWidth > 0 and iconWidth > 0 then
    local scale = portraitWidth * portrait:GetEffectiveScale() / (iconWidth * iconFrame:GetEffectiveScale())
    return { region = portrait, relativePoint = "CENTER", x = 0, y = 0, scale = scale, level = level }
  end
  local inset = iconHalfWidth(iconFrame) - Theme.LAYOUT.PHONE_CORNER_OVERLAP
  return { region = frame, relativePoint = "TOPLEFT", x = -inset, y = inset, scale = 1, level = level }
end

-- Saved position, for players with no button: from the frame's real edges.
function PhoneDock.CapturePosition(frame)
  return {
    anchorPoint = "TOPLEFT",
    relativePoint = "BOTTOMLEFT",
    x = frame.GetLeft and frame:GetLeft() or 0,
    y = frame.GetTop and frame:GetTop() or 0,
  }
end

ns.MessengerWindowPhoneDock = PhoneDock

return PhoneDock
