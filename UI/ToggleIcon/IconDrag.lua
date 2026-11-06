local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local captureFramePosition = UIHelpers.captureFramePosition

-- Drag-to-move for the toggle icon. A locked icon ignores drag starts; a drop
-- reports the new position through options.onPositionChanged.
local IconDrag = {}

-- Returns { setRideHandlers }. While the icon rides the phone window it is
-- pinned there, so a drag goes to these handlers: { beginDrag, endDrag }.
function IconDrag.Attach(frame, isLocked, options)
  local rideHandlers = nil
  local rideDragging = false

  local function beginDrag()
    if isLocked() then
      return
    end
    if rideHandlers then
      rideDragging = true
      rideHandlers.beginDrag()
      return
    end
    if frame.IsMovable == nil or frame:IsMovable() then
      frame:StartMoving()
    end
  end

  local function endDrag()
    if rideDragging then
      rideDragging = false
      if rideHandlers then
        rideHandlers.endDrag()
      end
      return
    end
    if rideHandlers then
      return
    end
    frame:StopMovingOrSizing()
    local nextState = captureFramePosition(frame)

    if options.onPositionChanged then
      options.onPositionChanged(nextState)
    end
  end

  frame:SetScript("OnDragStart", beginDrag)
  frame:SetScript("OnDragStop", endDrag)

  return {
    setRideHandlers = function(handlers)
      rideHandlers = handlers
    end,
  }
end

ns.ToggleIconIconDrag = IconDrag
return IconDrag
