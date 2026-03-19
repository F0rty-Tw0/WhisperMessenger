local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local function trace(...)
  if type(_G.print) == "function" then
    _G.print("[WM]", ...)
  end
end

local ToggleIcon = {}

function ToggleIcon.Create(factory, options)
  options = options or {}

  local parent = options.parent or _G.UIParent
  local state = options.state or {}
  local anchorPoint = state.anchorPoint or "CENTER"
  local relativePoint = state.relativePoint or anchorPoint
  local x = state.x or 0
  local y = state.y or 0

  local frame = factory.CreateFrame("Button", "WhisperMessengerToggleIcon", parent)
  frame:SetSize(36, 36)
  frame:SetPoint(anchorPoint, parent, relativePoint, x, y)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  if background.SetColorTexture then
    background:SetColorTexture(0.18, 0.5, 0.95, 0.95)
  end

  local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  label:SetPoint("CENTER", frame, "CENTER", 0, 0)
  label:SetText("WM")

  if frame.SetScript then
    frame:SetScript("OnClick", function()
      trace("icon click")
      if options.onToggle then
        options.onToggle()
      end
    end)

    frame:SetScript("OnDragStart", function(self)
      if self.IsMovable == nil or self:IsMovable() then
        self:StartMoving()
        trace("icon drag start")
      end
    end)

    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, _, relative, offsetX, offsetY
      if self.GetPoint then
        point, _, relative, offsetX, offsetY = self:GetPoint()
      else
        local savedPoint = self.point or {}
        point, relative, offsetX, offsetY = savedPoint[1], savedPoint[3], savedPoint[4], savedPoint[5]
      end

      local nextState = {
        anchorPoint = point or "CENTER",
        relativePoint = relative or point or "CENTER",
        x = offsetX or 0,
        y = offsetY or 0,
      }

      trace("icon drag stop", nextState.anchorPoint, nextState.x, nextState.y)
      if options.onPositionChanged then
        options.onPositionChanged(nextState)
      end
    end)
  end

  trace("icon created", anchorPoint, x, y)

  return {
    frame = frame,
    background = background,
    label = label,
  }
end

ns.ToggleIcon = ToggleIcon

return ToggleIcon
