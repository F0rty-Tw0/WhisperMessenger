local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local captureFramePosition = UIHelpers.captureFramePosition

-- Drag-to-move for the toggle icon. A locked icon ignores drag starts; a drop
-- reports the new position through options.onPositionChanged.
local IconDrag = {}

function IconDrag.Attach(frame, isLocked, options)
  frame:SetScript("OnDragStart", function(self)
    if isLocked() then
      return
    end
    if self.IsMovable == nil or self:IsMovable() then
      self:StartMoving()
    end
  end)

  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local nextState = captureFramePosition(self)

    if options.onPositionChanged then
      options.onPositionChanged(nextState)
    end
  end)
end

ns.ToggleIconIconDrag = IconDrag
return IconDrag
