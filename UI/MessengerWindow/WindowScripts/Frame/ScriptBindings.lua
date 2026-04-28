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

  local function composerHasFocus()
    local input = options.composerInput
    if input == nil or type(input.HasFocus) ~= "function" then
      return false
    end
    local ok, focused = pcall(function()
      return input:HasFocus() == true
    end)
    return ok and focused == true
  end

  local function isMouseOverFrame()
    if frame == nil or type(frame.IsMouseOver) ~= "function" then
      return false
    end
    local ok, over = pcall(function()
      return frame:IsMouseOver() == true
    end)
    return ok and over == true
  end

  -- Strata/Raise transitions must never pull keyboard focus away from
  -- the composer. WoW's click-on-non-EditBox flow and frame:Raise() can
  -- clear an EditBox's focus as a side effect — when the composer had
  -- focus before the change, restore it afterwards so mouse-over / click
  -- promotions don't interrupt the user's typing.
  local function preserveComposerFocusAround(fn)
    local hadFocus = composerHasFocus()
    fn()
    if hadFocus and not composerHasFocus() then
      local input = options.composerInput
      if input and type(input.SetFocus) == "function" then
        input:SetFocus()
      end
    end
  end

  local function promoteStrata()
    preserveComposerFocusAround(function()
      if frame and type(frame.SetFrameStrata) == "function" then
        frame:SetFrameStrata("HIGH")
      end
      if frame and type(frame.Raise) == "function" then
        frame:Raise()
      end
    end)
  end

  local function demoteStrataIfIdle()
    if composerHasFocus() or isMouseOverFrame() then
      return
    end
    preserveComposerFocusAround(function()
      if frame and type(frame.SetFrameStrata) == "function" then
        frame:SetFrameStrata("MEDIUM")
      end
    end)
  end

  if frame and frame.SetScript then
    frame:SetScript("OnShow", function()
      alphaElapsed = 0
      options.refreshWindowAlpha(true)
      if options.composerInput and options.getAutoFocusChatInput and options.getAutoFocusChatInput() and options.composerInput.SetFocus then
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

    frame:SetScript("OnMouseDown", function()
      promoteStrata()
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
      -- Intentionally do NOT demote strata here. Mouse-over alone (e.g.
      -- moving the cursor onto the Auction House or another addon) must
      -- not send our window to the back — only an explicit click outside
      -- our frame should, handled via GLOBAL_MOUSE_DOWN below.
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

    -- GLOBAL_MOUSE_DOWN fires for every mouse click in the UI. We use it
    -- to detect "user engaged with another window" — when they click
    -- somewhere the messenger isn't, drop our strata so their target
    -- window comes forward. Clicks on our own frame hit OnMouseDown which
    -- promotes instead, and here we skip demotion when the cursor is
    -- still over us.
    if type(frame.RegisterEvent) == "function" then
      frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end
    frame:SetScript("OnEvent", function(self, event)
      if event == "GLOBAL_MOUSE_DOWN" and not isMouseOverFrame() then
        demoteStrataIfIdle()
      end
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
