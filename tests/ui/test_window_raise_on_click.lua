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
    updatePreview = noop,
    isDragging = function()
      return false
    end,
  }
end

local function buildHarness(options)
  options = options or {}
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Frame", nil, parent)
  local resizeGrip = factory.CreateFrame("Frame", nil, parent)
  local contactsResizeHandle = factory.CreateFrame("Frame", nil, parent)

  frame:SetFrameStrata("MEDIUM")

  local raiseCalls = 0
  function frame:Raise()
    raiseCalls = raiseCalls + 1
  end

  local composerInput = options.composerInput
  local resizeStub = makeResizeStub()

  ScriptBindings.Bind({
    frame = frame,
    resizeGrip = resizeGrip,
    contactsResizeHandle = contactsResizeHandle,
    frameTheme = { WINDOW_ALPHA_UPDATE_INTERVAL = 0.1 },
    windowResize = resizeStub,
    contactsResize = resizeStub,
    relayoutWindow = noop,
    isSuppressSizeChangedRelayout = function()
      return false
    end,
    refreshWindowAlpha = noop,
    composerInput = composerInput,
    getAutoFocusChatInput = function()
      return false
    end,
    buildState = function()
      return {}
    end,
    onPositionChanged = noop,
    trace = noop,
  })

  return {
    frame = frame,
    scripts = frame.scripts or {},
    getRaiseCalls = function()
      return raiseCalls
    end,
  }
end

return function()
  -- OnMouseDown promotes strata to HIGH and raises within strata.
  do
    local h = buildHarness({})
    local onMouseDown = h.scripts.OnMouseDown
    assert(type(onMouseDown) == "function", "expected frame to have OnMouseDown handler")

    onMouseDown(h.frame, "LeftButton")
    assert(
      h.frame.frameStrata == "HIGH",
      "expected OnMouseDown to promote strata to HIGH so the window sits above other windows; got "
        .. tostring(h.frame.frameStrata)
    )
    assert(h.getRaiseCalls() == 1, "expected OnMouseDown to call frame:Raise() within the promoted strata")
  end

  -- OnLeave with no composer focus drops strata back to MEDIUM.
  do
    local h = buildHarness({})
    h.scripts.OnMouseDown(h.frame, "LeftButton")
    assert(h.frame.frameStrata == "HIGH", "precondition: window promoted after click")

    local onLeave = h.scripts.OnLeave
    assert(type(onLeave) == "function", "expected frame to have OnLeave handler")
    onLeave(h.frame)
    assert(
      h.frame.frameStrata == "MEDIUM",
      "expected OnLeave to demote strata to MEDIUM when composer has no focus; got " .. tostring(h.frame.frameStrata)
    )
  end

  -- OnLeave while composer still focused keeps strata HIGH.
  do
    local composerInput = {
      _focused = true,
      HasFocus = function(self)
        return self._focused
      end,
    }
    local h = buildHarness({ composerInput = composerInput })
    h.scripts.OnMouseDown(h.frame, "LeftButton")
    assert(h.frame.frameStrata == "HIGH", "precondition: window promoted after click")

    h.scripts.OnLeave(h.frame)
    assert(
      h.frame.frameStrata == "HIGH",
      "expected strata to stay HIGH while composer retains keyboard focus; got " .. tostring(h.frame.frameStrata)
    )
  end
end
