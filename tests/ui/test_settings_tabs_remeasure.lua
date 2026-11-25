local FakeUI = require("tests.helpers.fake_ui")
local SettingsTabs = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Buttons.SettingsTabs")

-- Runs fn(panel, timers, state) on one wired page with a fake C_Timer.
local function withPage(fn)
  local savedTimer = rawget(_G, "C_Timer")
  local timers = {}
  rawset(_G, "C_Timer", {
    After = function(_, callback)
      timers[#timers + 1] = callback
    end,
  })
  local ok, err = pcall(function()
    local factory = FakeUI.NewFactory()
    local panel = factory.CreateFrame("Frame", nil, nil)
    local tab = factory.CreateFrame("Button", nil, nil)
    local content = factory.CreateFrame("Frame", nil, nil)
    local state = { measures = 0 }
    SettingsTabs.Wire({
      settingsTabs = { tab },
      settingsPanels = { panel },
      optionsScrollView = { content = content },
      scrollView = { Sync = function() end, SetVerticalScroll = function() end },
      measurePanelContentHeight = function()
        state.measures = state.measures + 1
        return 500
      end,
    })
    for index = #timers, 1, -1 do
      timers[index] = nil
    end
    state.measures = 0
    fn(panel, timers, state)
  end)
  rawset(_G, "C_Timer", savedTimer)
  assert(ok, err)
end

return function()
  -- test_remeasure_asked_twice_in_a_frame_runs_once
  withPage(function(panel, timers)
    panel._wmRemeasure()
    panel._wmRemeasure()
    assert(#timers == 1, "one timer per page and frame, got " .. #timers)
  end)

  -- test_remeasure_works_again_on_a_later_frame
  withPage(function(panel, timers, state)
    panel._wmRemeasure()
    timers[1]()
    panel._wmRemeasure()
    assert(#timers == 2, "a later ask gets its own timer, got " .. #timers)
    timers[2]()
    assert(state.measures == 2, "each run measures, got " .. state.measures)
  end)
end
