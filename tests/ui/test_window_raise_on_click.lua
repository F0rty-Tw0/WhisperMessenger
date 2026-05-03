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
  -- OnShow must promote strata so the messenger sits above other windows
  -- the user already has open (Auction House, World Map, etc.). Without
  -- this, opening the messenger while AH or the map is up would leave our
  -- window stuck behind those HIGH-strata frames at MEDIUM.
  do
    local h = buildHarness({})
    assert(h.frame.frameStrata == "MEDIUM", "precondition: window starts at MEDIUM strata")

    local onShow = h.scripts.OnShow
    assert(type(onShow) == "function", "expected frame to have OnShow handler")
    onShow(h.frame)

    assert(
      h.frame.frameStrata == "HIGH",
      "expected OnShow to promote strata to HIGH so the window sits above AH/Map; got " .. tostring(h.frame.frameStrata)
    )
    assert(h.getRaiseCalls() >= 1, "expected OnShow to call frame:Raise() within the promoted strata")
  end

  -- OnMouseDown promotes strata to HIGH and raises within strata.
  do
    local h = buildHarness({})
    local onMouseDown = h.scripts.OnMouseDown
    assert(type(onMouseDown) == "function", "expected frame to have OnMouseDown handler")

    onMouseDown(h.frame, "LeftButton")
    assert(
      h.frame.frameStrata == "HIGH",
      "expected OnMouseDown to promote strata to HIGH so the window sits above other windows; got " .. tostring(h.frame.frameStrata)
    )
    assert(h.getRaiseCalls() == 1, "expected OnMouseDown to call frame:Raise() within the promoted strata")
  end

  -- OnLeave must never demote on its own — demotion is driven exclusively
  -- by GLOBAL_MOUSE_DOWN outside our frame. This prevents mouse-over of
  -- other windows (e.g. Auction House) from sending us to the back.
  do
    local h = buildHarness({})
    h.scripts.OnMouseDown(h.frame, "LeftButton")
    assert(h.frame.frameStrata == "HIGH", "precondition: window promoted after click")

    local onLeave = h.scripts.OnLeave
    assert(type(onLeave) == "function", "expected frame to have OnLeave handler")
    onLeave(h.frame)
    assert(
      h.frame.frameStrata == "HIGH",
      "expected strata to stay HIGH on mouse-leave — demotion should wait for an outside click; got " .. tostring(h.frame.frameStrata)
    )
  end

  -- Even with composer focus active, mouse-leave must not demote.
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
    assert(h.frame.frameStrata == "HIGH", "expected strata to stay HIGH while composer retains keyboard focus; got " .. tostring(h.frame.frameStrata))
  end

  -- Mouse-over alone (no click) must NOT demote strata. Hovering over the
  -- Auction House or another window while our messenger is still the one
  -- the user is using should not send our window to the back.
  do
    local h = buildHarness({})
    h.scripts.OnMouseDown(h.frame, "LeftButton")
    assert(h.frame.frameStrata == "HIGH", "precondition: window promoted after click")

    -- Simulate the user moving the mouse off our frame (e.g. onto AH).
    -- OnLeave must keep strata HIGH until they actually click somewhere else.
    h.scripts.OnLeave(h.frame)
    assert(
      h.frame.frameStrata == "HIGH",
      "expected strata to stay HIGH on mouse-leave alone (demote only on outside click); got " .. tostring(h.frame.frameStrata)
    )
  end

  -- Clicking somewhere outside our frame (e.g. on the Auction House) should
  -- demote our strata. GLOBAL_MOUSE_DOWN is the WoW event that fires for
  -- every click, so we use it to detect "user engaged with another window".
  do
    local h = buildHarness({})
    h.scripts.OnMouseDown(h.frame, "LeftButton")
    assert(h.frame.frameStrata == "HIGH", "precondition: window promoted after click")

    -- Pretend the mouse moved off our frame and the user clicked elsewhere.
    h.frame.mouseOver = false
    assert(type(h.scripts.OnEvent) == "function", "expected OnEvent handler on frame to listen for GLOBAL_MOUSE_DOWN")
    assert(h.frame:IsEventRegistered("GLOBAL_MOUSE_DOWN"), "expected frame to register GLOBAL_MOUSE_DOWN for outside-click demotion")
    h.scripts.OnEvent(h.frame, "GLOBAL_MOUSE_DOWN", "LeftButton")
    assert(h.frame.frameStrata == "MEDIUM", "expected outside click to demote strata to MEDIUM; got " .. tostring(h.frame.frameStrata))
  end

  -- Clicks inside our frame must NOT demote — only clicks outside do.
  do
    local h = buildHarness({})
    h.scripts.OnMouseDown(h.frame, "LeftButton")
    assert(h.frame.frameStrata == "HIGH", "precondition: window promoted after click")

    h.frame.mouseOver = true
    h.scripts.OnEvent(h.frame, "GLOBAL_MOUSE_DOWN", "LeftButton")
    assert(h.frame.frameStrata == "HIGH", "expected clicks inside our frame to leave strata HIGH; got " .. tostring(h.frame.frameStrata))
  end

  -- Clicking (or otherwise focusing) the composer input must promote the
  -- window the same way clicking the frame chrome does. Without this, the
  -- user can type into the composer while the window stays behind AH/Map
  -- because the EditBox swallows the click and the frame's OnMouseDown
  -- never fires.
  do
    local hookedScripts = {}
    local composerInput = {
      _focused = false,
      HasFocus = function(self)
        return self._focused
      end,
      SetFocus = function(self)
        self._focused = true
      end,
      HookScript = function(self, scriptName, handler)
        hookedScripts[scriptName] = hookedScripts[scriptName] or {}
        hookedScripts[scriptName][#hookedScripts[scriptName] + 1] = handler
      end,
    }
    local h = buildHarness({ composerInput = composerInput })
    assert(h.frame.frameStrata == "MEDIUM", "precondition: window starts at MEDIUM strata")

    local focusHandlers = hookedScripts["OnEditFocusGained"]
    assert(
      type(focusHandlers) == "table" and #focusHandlers >= 1,
      "expected ScriptBindings to hook OnEditFocusGained on composer input so clicks into the input promote the window"
    )

    local prevRaiseCalls = h.getRaiseCalls()
    composerInput._focused = true
    for _, handler in ipairs(focusHandlers) do
      handler(composerInput)
    end

    assert(h.frame.frameStrata == "HIGH", "expected composer input focus to promote strata to HIGH; got " .. tostring(h.frame.frameStrata))
    assert(h.getRaiseCalls() >= prevRaiseCalls + 1, "expected composer input focus to call frame:Raise() within the promoted strata")
  end

  -- OnMouseDown must not steal keyboard focus from the composer, even when
  -- frame:Raise() (or the click itself) would clear it as a side effect.
  -- Simulates WoW's real behavior where clicking elsewhere on the frame
  -- can drop EditBox focus — promoteStrata should restore it.
  do
    local setFocusCalls = 0
    local composerInput = {
      _focused = true,
      HasFocus = function(self)
        return self._focused
      end,
      SetFocus = function(self)
        self._focused = true
        setFocusCalls = setFocusCalls + 1
      end,
    }
    local h = buildHarness({ composerInput = composerInput })
    -- Make frame:Raise() clear composer focus the way a WoW click can.
    local originalRaise = h.frame.Raise
    function h.frame:Raise()
      composerInput._focused = false
      if originalRaise then
        originalRaise(self)
      end
    end

    h.scripts.OnMouseDown(h.frame, "LeftButton")
    assert(composerInput._focused == true, "expected composer focus to be restored after promoteStrata, even if Raise cleared it")
    assert(setFocusCalls == 1, "expected exactly one SetFocus call to restore composer focus; got " .. setFocusCalls)
  end
end
