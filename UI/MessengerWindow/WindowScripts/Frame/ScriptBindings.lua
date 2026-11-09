local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local EscapeOrder = ns.MessengerWindowWindowScriptsFrameEscapeOrder or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.EscapeOrder")
local EscapeKey = ns.MessengerWindowWindowScriptsFrameEscapeKey or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.EscapeKey")
local WindowStrata = ns.MessengerWindowWindowScriptsFrameWindowStrata
  or require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.WindowStrata")

local ScriptBindings = {}

function ScriptBindings.Bind(options)
  options = options or {}

  local frame = options.frame
  local resizeGrip = options.resizeGrip
  local contactsResizeHandle = options.contactsResizeHandle
  local windowResize = options.windowResize
  local contactsResize = options.contactsResize
  local relayoutWindow = options.relayoutWindow

  local alphaTicker = nil
  local escapeOrder = frame and EscapeOrder.New(frame, EscapeKey.New(frame), options.getEscapeClosesWindow) or nil

  local function updateResizeFromCursor()
    contactsResize.updateFromCursor()
    windowResize.updateFromCursor()
  end

  local function updateResizeOnly()
    updateResizeFromCursor()
  end

  local function updateFrameOnUpdate()
    if frame == nil or type(frame.SetScript) ~= "function" then
      return
    end
    if windowResize.isResizing() or contactsResize.isResizing() then
      frame:SetScript("OnUpdate", updateResizeOnly)
    else
      frame:SetScript("OnUpdate", nil)
    end
  end

  local function startAlphaTicker()
    local timer = _G.C_Timer
    if alphaTicker ~= nil or type(timer) ~= "table" or type(timer.NewTicker) ~= "function" then
      return
    end
    alphaTicker = timer.NewTicker(options.frameTheme.WINDOW_ALPHA_UPDATE_INTERVAL, function()
      if not windowResize.isResizing() then
        options.refreshWindowAlpha()
      end
    end)
  end

  local function stopAlphaTicker()
    if alphaTicker == nil then
      return
    end
    alphaTicker:Cancel()
    alphaTicker = nil
  end

  local strata = WindowStrata.New(frame, options, escapeOrder)
  local promoteStrata = strata.promote
  local demoteStrataIfIdle = strata.demoteIfIdle
  local isPointerOnWindow = strata.isPointerOnWindow

  -- GLOBAL_MOUSE_DOWN fires for every click in the UI: a click elsewhere
  -- sends the window back (and hands ESC to the clicked window), a click on
  -- it brings it forward. Listen only while shown: hidden costs nothing.
  local function setOutsideClickListening(listening)
    if listening and type(frame.RegisterEvent) == "function" then
      frame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    elseif not listening and type(frame.UnregisterEvent) == "function" then
      frame:UnregisterEvent("GLOBAL_MOUSE_DOWN")
    end
  end

  if frame and frame.SetScript then
    frame:SetScript("OnShow", function()
      setOutsideClickListening(true)
      startAlphaTicker()
      options.refreshWindowAlpha(true)
      -- Promote on Show so we sit above HIGH-strata frames the user already
      -- has open (Auction House, World Map). Outside-click still demotes.
      promoteStrata()
      if options.composerInput and options.getAutoFocusChatInput and options.getAutoFocusChatInput() and options.composerInput.SetFocus then
        options.composerInput:SetFocus()
      end
    end)

    frame:SetScript("OnHide", function()
      escapeOrder.release()
      setOutsideClickListening(false)
      stopAlphaTicker()
      contactsResize.reset()
      windowResize.reset()
      updateFrameOnUpdate()
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
      -- No demote here: only a click elsewhere (GLOBAL_MOUSE_DOWN below)
      -- sends the window back, never mouse-over alone.
    end)

    if type(frame.IsShown) == "function" and frame:IsShown() then
      setOutsideClickListening(true)
      escapeOrder.claim()
    end
    frame:SetScript("OnEvent", function(self, event)
      if event ~= "GLOBAL_MOUSE_DOWN" then
        return
      end
      -- Buttons inside the window swallow the click, so the frame's own
      -- OnMouseDown never fires for them; promote from here instead.
      if isPointerOnWindow() then
        promoteStrata()
      else
        escapeOrder.yieldToClickedWindow()
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
      end
    end)

    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local nextState = options.buildState(self)
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
      updateFrameOnUpdate()
    end)
    updateFrameOnUpdate()
  end

  -- The composer EditBox swallows clicks, so OnMouseDown on the frame
  -- doesn't fire when the user clicks into the input. Hook focus-gained on
  -- the input so clicking it also brings the window above AH/Map.
  if options.composerInput and type(options.composerInput.HookScript) == "function" then
    options.composerInput:HookScript("OnEditFocusGained", function()
      promoteStrata()
    end)
  end

  if resizeGrip and resizeGrip.SetScript then
    resizeGrip:SetScript("OnMouseDown", function(_self, button)
      windowResize.start(button)
      updateFrameOnUpdate()
    end)

    resizeGrip:SetScript("OnMouseUp", function(_self, button)
      windowResize.stop(button)
      updateFrameOnUpdate()
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
      updateFrameOnUpdate()
    end)

    contactsResizeHandle:SetScript("OnMouseUp", function(_self, button)
      contactsResize.stop(button)
      updateFrameOnUpdate()
    end)
  end

  return {
    refreshEscape = function()
      if escapeOrder then
        escapeOrder.refresh()
      end
    end,
  }
end

ns.MessengerWindowWindowScriptsFrameScriptBindings = ScriptBindings

return ScriptBindings
