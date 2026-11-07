local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

-- Where the phone window opens and where the floating button rides on it.
-- Every window style declares its icon spot (chrome.iconSlot), so this has no
-- per-style cases: with Open at saved spot off, the window opens with its spot
-- on the button; the button grows or shrinks to fill the spot.
local PhoneDock = {}

-- Spot centre relative to the window's top-left corner. Before the client has
-- laid the window out it counts as the corner: the glide finds the real spot.
local function slotOffset(frame, slot)
  local left = frame.GetLeft and frame:GetLeft()
  local top = frame.GetTop and frame:GetTop()
  local x, y = nil, nil
  if slot.GetCenter then
    x, y = slot:GetCenter()
  end
  if not (left and top and x and y) then
    return 0, 0
  end
  return x - left, y - top
end

-- Places the window so its icon spot lands on the button. The window stays
-- clamped to the screen, so near an edge the button travels further to reach it.
function PhoneDock.Place(frame, slot, iconFrame)
  if iconFrame == nil or not iconFrame.GetCenter then
    return
  end
  local iconX, iconY = iconFrame:GetCenter()
  if iconX == nil then
    return
  end
  local ratio = iconFrame:GetEffectiveScale() / frame:GetEffectiveScale()
  local offsetX, offsetY = slotOffset(frame, slot)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent() or _G.UIParent, "BOTTOMLEFT", iconX * ratio - offsetX, iconY * ratio - offsetY)
end

-- Where a window with no saved position starts. Placed by its corner, so a
-- window wide for settings is centred once it returns to phone size.
function PhoneDock.Center(frame)
  local L = Theme.LAYOUT
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent() or _G.UIParent, "CENTER", -L.PHONE_WINDOW_WIDTH / 2, L.PHONE_WINDOW_HEIGHT / 2)
end

-- The corner spot sticks out past the window's corner; the screen clamp only
-- knows the window's own edges, so it is told to reach over the spot. False
-- while the client has no position for them yet.
function PhoneDock.ClampToSpot(frame, slot)
  local frameLeft = frame.GetLeft and frame:GetLeft()
  local frameTop = frame.GetTop and frame:GetTop()
  local slotLeft = slot.GetLeft and slot:GetLeft()
  local slotTop = slot.GetTop and slot:GetTop()
  if not (frameLeft and frameTop and slotLeft and slotTop) then
    return false
  end
  local _, right, _, bottom = frame:GetClampRectInsets()
  frame:SetClampRectInsets(-math.max(0, frameLeft - slotLeft), right, math.max(0, slotTop - frameTop), bottom)
  return true
end

-- What IconRide needs to carry the button onto the spot.
function PhoneDock.RideTarget(slot, iconFrame)
  local iconWidth = iconFrame:GetWidth() or 0
  local slotWidth = slot:GetWidth() or 0
  local scale = 1
  if slotWidth > 0 and iconWidth > 0 then
    -- The result is the button's own scale, so what it inherits is all that
    -- counts: a button already riding carries its ride scale.
    local inherited = iconFrame:GetEffectiveScale() / iconFrame:GetScale()
    scale = slotWidth * slot:GetEffectiveScale() / (iconWidth * inherited)
  end
  return { region = slot, relativePoint = "CENTER", x = 0, y = 0, scale = scale, level = Theme.LAYOUT.PHONE_RIDE_FRAME_LEVEL }
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
