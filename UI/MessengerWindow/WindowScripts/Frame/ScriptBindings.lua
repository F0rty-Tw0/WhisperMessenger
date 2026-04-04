local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScriptBindings = {}

function ScriptBindings.Bind(options)
  options = options or {}

  local frame = options.frame
  local resizeGrip = options.resizeGrip
  local contactsResizeHandle = options.contactsResizeHandle
  local windowResize = options.windowResize
  local contactsResize = options.contactsResize
  local relayoutWindow = options.relayoutWindow

  local alphaElapsed = 0

  if frame and frame.SetScript then
    frame:SetScript("OnShow", function()
      alphaElapsed = 0
      options.refreshWindowAlpha(true)
      if
        options.composerInput
        and options.getAutoFocusChatInput
        and options.getAutoFocusChatInput()
        and options.composerInput.SetFocus
      then
        options.composerInput:SetFocus()
      end
      options.trace("window shown")
    end)

    frame:SetScript("OnHide", function()
      alphaElapsed = 0
      contactsResize.reset()
      windowResize.reset()
      options.trace("window hidden")
    end)

    frame:SetScript("OnEnter", function()
      if windowResize.isResizing() then
        return
      end
      options.refreshWindowAlpha(true)
    end)

    frame:SetScript("OnLeave", function()
      if windowResize.isResizing() then
        return
      end
      options.refreshWindowAlpha()
    end)

    frame:SetScript("OnUpdate", function(_, elapsed)
      alphaElapsed = alphaElapsed + (elapsed or 0)
      if not windowResize.isResizing() and alphaElapsed >= options.frameTheme.WINDOW_ALPHA_UPDATE_INTERVAL then
        alphaElapsed = 0
        options.refreshWindowAlpha()
      end
      contactsResize.updateFromCursor()
      windowResize.updateFromCursor()
    end)

    frame:SetScript("OnSizeChanged", function(_self, w, h)
      if options.isSuppressSizeChangedRelayout() then
        return
      end
      relayoutWindow(w, h, nil, false)
    end)

    frame:SetScript("OnDragStart", function(self)
      if self.IsMovable == nil or self:IsMovable() then
        self:StartMoving()
        options.trace("window drag start")
      end
    end)

    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local nextState = options.buildState(self)
      options.trace("window drag stop", nextState.anchorPoint, nextState.x, nextState.y)
      if options.onPositionChanged then
        options.onPositionChanged(nextState)
      end
    end)

    local previousFrameMouseUp = frame.GetScript and frame:GetScript("OnMouseUp")
    frame:SetScript("OnMouseUp", function(self, button)
      if previousFrameMouseUp then
        previousFrameMouseUp(self, button)
      end
      windowResize.stop(button)
      contactsResize.stop(button)
    end)
  end

  if resizeGrip and resizeGrip.SetScript then
    resizeGrip:SetScript("OnMouseDown", function(_self, button)
      windowResize.start(button)
    end)

    resizeGrip:SetScript("OnMouseUp", function(_self, button)
      windowResize.stop(button)
    end)
  end

  if contactsResizeHandle and contactsResizeHandle.SetScript then
    contactsResizeHandle:SetScript("OnEnter", function()
      contactsResize.setHighlight(true)
    end)

    contactsResizeHandle:SetScript("OnLeave", function()
      if not contactsResize.isResizing() then
        contactsResize.setHighlight(false)
      end
    end)

    contactsResizeHandle:SetScript("OnMouseDown", function(_self, button)
      contactsResize.start(button)
    end)

    contactsResizeHandle:SetScript("OnMouseUp", function(_self, button)
      contactsResize.stop(button)
    end)
  end
end

ns.MessengerWindowWindowScriptsFrameScriptBindings = ScriptBindings

return ScriptBindings
