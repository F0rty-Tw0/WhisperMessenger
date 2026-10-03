local FakeUI = require("tests.helpers.fake_ui")
local ScriptBindings = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.ScriptBindings")

local function noop() end

local function makeResizeStub()
  return {
    isResizing = function()
      return false
    end,
    stop = noop,
    reset = noop,
    start = noop,
    setHighlight = noop,
    updateFromCursor = noop,
  }
end

local function bindFrame(shownAtBind)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", nil, parent)
  frame.shown = shownAtBind == true
  local resizeStub = makeResizeStub()

  ScriptBindings.Bind({
    frame = frame,
    frameTheme = { WINDOW_ALPHA_UPDATE_INTERVAL = 0.1 },
    windowResize = resizeStub,
    contactsResize = resizeStub,
    relayoutWindow = noop,
    isSuppressSizeChangedRelayout = function()
      return false
    end,
    refreshWindowAlpha = noop,
    getAutoFocusChatInput = function()
      return false
    end,
    buildState = function()
      return {}
    end,
  })

  return frame
end

return function()
  -- test_hidden_frame_does_not_listen_for_global_mouse_down
  do
    local frame = bindFrame(false)
    assert(not frame:IsEventRegistered("GLOBAL_MOUSE_DOWN"), "hidden window must not run a handler on every click in the game")
  end

  -- test_show_registers_global_mouse_down
  do
    local frame = bindFrame(false)
    frame:Show()
    assert(frame:IsEventRegistered("GLOBAL_MOUSE_DOWN"), "shown window must listen for outside clicks")
  end

  -- test_hide_unregisters_global_mouse_down
  do
    local frame = bindFrame(false)
    frame:Show()
    frame:Hide()
    assert(not frame:IsEventRegistered("GLOBAL_MOUSE_DOWN"), "hiding the window must stop listening for clicks")
  end

  -- test_frame_shown_at_bind_registers_immediately
  do
    local frame = bindFrame(true)
    assert(frame:IsEventRegistered("GLOBAL_MOUSE_DOWN"), "window already shown at bind time must listen for outside clicks")
  end

  -- test_outside_click_still_demotes_strata_while_shown
  do
    local frame = bindFrame(false)
    frame:Show()
    assert(frame.frameStrata == "HIGH", "precondition: show promotes strata")
    frame.mouseOver = false
    frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN", "LeftButton")
    assert(frame.frameStrata == "MEDIUM", "outside click must demote strata; got " .. tostring(frame.frameStrata))
  end
end
