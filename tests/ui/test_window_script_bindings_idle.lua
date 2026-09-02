local FakeUI = require("tests.helpers.fake_ui")
local ScriptBindings = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.ScriptBindings")

local function noop() end

local function makeResizeController()
  local resizing = false
  local updateCalls = 0

  return {
    isResizing = function()
      return resizing
    end,
    start = function(button)
      resizing = button == "LeftButton"
    end,
    stop = function(button)
      if button == "LeftButton" then
        resizing = false
      end
    end,
    reset = function()
      resizing = false
    end,
    updateFromCursor = function()
      updateCalls = updateCalls + 1
    end,
    setHighlight = noop,
    getUpdateCalls = function()
      return updateCalls
    end,
  }
end

return function()
  local previousTimer = _G.C_Timer
  local timer = { newTickerCalls = 0, tickers = {} }

  rawset(_G, "C_Timer", {
    NewTicker = function(interval, callback)
      timer.newTickerCalls = timer.newTickerCalls + 1
      local ticker = { interval = interval, callback = callback, cancelled = false }

      function ticker:Cancel()
        self.cancelled = true
      end

      timer.tickers[#timer.tickers + 1] = ticker
      return ticker
    end,
  })

  local ok, err = pcall(function()
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "UIParent", nil)
    local frame = factory.CreateFrame("Frame", nil, parent)
    local resizeGrip = factory.CreateFrame("Frame", nil, frame)
    local contactsResizeHandle = factory.CreateFrame("Frame", nil, frame)
    local windowResize = makeResizeController()
    local contactsResize = makeResizeController()
    local refreshCalls = {}

    ScriptBindings.Bind({
      frame = frame,
      resizeGrip = resizeGrip,
      contactsResizeHandle = contactsResizeHandle,
      frameTheme = { WINDOW_ALPHA_UPDATE_INTERVAL = 0.1 },
      windowResize = windowResize,
      contactsResize = contactsResize,
      relayoutWindow = noop,
      isSuppressSizeChangedRelayout = function()
        return false
      end,
      refreshWindowAlpha = function(force)
        refreshCalls[#refreshCalls + 1] = force == true
      end,
      getAutoFocusChatInput = function()
        return false
      end,
      buildState = function()
        return {}
      end,
      trace = noop,
    })

    assert(frame:GetScript("OnUpdate") == nil, "expected idle window to have no OnUpdate when C_Timer.NewTicker is available")

    frame:Show()
    assert(timer.newTickerCalls == 1, "expected OnShow to create one alpha ticker")
    assert(timer.tickers[1].interval == 0.1, "expected alpha ticker interval to be 0.1 seconds")

    timer.tickers[1].callback()
    assert(refreshCalls[2] == false, "expected alpha ticker to refresh window alpha")

    frame:Show()
    assert(timer.newTickerCalls == 1, "expected repeated OnShow not to duplicate alpha ticker")

    frame:Hide()
    assert(timer.tickers[1].cancelled, "expected OnHide to cancel alpha ticker")

    resizeGrip.scripts.OnMouseDown(resizeGrip, "LeftButton")
    local onUpdate = frame:GetScript("OnUpdate")
    assert(type(onUpdate) == "function", "expected left-button resize start to install OnUpdate")

    onUpdate(frame, 0.1)
    assert(windowResize.getUpdateCalls() == 1, "expected resize OnUpdate to update window resize from cursor")

    resizeGrip.scripts.OnMouseUp(resizeGrip, "LeftButton")
    assert(frame:GetScript("OnUpdate") == nil, "expected resize stop to remove OnUpdate while idle")
  end)

  rawset(_G, "C_Timer", previousTimer)
  if not ok then
    error(err, 0)
  end
end
