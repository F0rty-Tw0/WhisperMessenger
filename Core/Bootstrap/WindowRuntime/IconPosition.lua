local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IconPosition = {}

function IconPosition.Apply(icon, nextState, uiParent)
  local frame = icon and icon.frame
  if frame and type(frame.SetPoint) == "function" then
    if type(frame.ClearAllPoints) == "function" then
      frame:ClearAllPoints()
    end
    local iconParent
    if type(frame.GetParent) == "function" then
      iconParent = frame:GetParent()
    end
    iconParent = iconParent or frame.parent or uiParent
    frame:SetPoint(nextState.anchorPoint, iconParent, nextState.relativePoint, nextState.x, nextState.y)
  end
  return nextState
end

ns.BootstrapWindowRuntimeIconPosition = IconPosition

return IconPosition
