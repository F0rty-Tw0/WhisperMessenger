local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

-- Where the phone window opens and where the floating button rides on it.
-- Every window style declares one icon spot (chrome.iconSlot), so this has no
-- per-style cases: the window opens at its own spot, and the button grows to
-- fill the spot.
local PhoneDock = {}

-- Where a window with no saved position starts. Placed by its corner, so a
-- window wide for settings is centred once it returns to phone size.
function PhoneDock.Center(frame)
  local L = Theme.LAYOUT
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent() or _G.UIParent, "CENTER", -L.PHONE_WINDOW_WIDTH / 2, L.PHONE_WINDOW_HEIGHT / 2)
end

-- The spot sticks out past the window's corner; the screen clamp only knows
-- the window's own edges, so it is told to reach over the spot. False while
-- the client has no position for them yet.
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
