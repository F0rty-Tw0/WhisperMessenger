local ScrollView = require("WhisperMessenger.UI.ScrollView")
local Metrics = require("WhisperMessenger.UI.ScrollView.Metrics")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()

  -- test_get_range_falls_back_when_wow_returns_zero

  do
    local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
      width = 300,
      height = 200,
    })

    -- Content is taller than viewport
    view.content:SetSize(300, 600)

    -- Simulate stale WoW layout: GetVerticalScrollRange returns 0
    view.scrollFrame.GetVerticalScrollRange = function()
      return 0
    end

    local range = Metrics.GetRange(view)
    assert(range == 400, "GetRange should fall back to manual calc (600 - 200 = 400), got: " .. tostring(range))
  end

  -- test_refresh_metrics_snap_to_end_with_stale_layout

  do
    local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
      width = 300,
      height = 200,
    })

    -- Simulate stale WoW layout: GetVerticalScrollRange returns 0
    -- but SetVerticalScroll still accepts any value (WoW behavior)
    view.scrollFrame.GetVerticalScrollRange = function()
      return 0
    end
    view.scrollFrame.SetVerticalScroll = function(self, v)
      self.verticalScroll = v
    end

    Metrics.RefreshMetrics(view, 600, true)

    local offset = view.scrollFrame.verticalScroll or 0
    assert(offset > 0, "snapToEnd should scroll to bottom even with stale layout, got offset: " .. tostring(offset))
    assert(offset == 400, "snapToEnd offset should be 400 (600 - 200), got: " .. tostring(offset))
  end

  -- test_refresh_metrics_snap_to_end_normal_case

  do
    local view = ScrollView.Create(factory, factory.CreateFrame("Frame", nil, nil), {
      width = 300,
      height = 200,
    })

    Metrics.RefreshMetrics(view, 600, true)

    local offset = view.scrollFrame:GetVerticalScroll()
    assert(offset == 400, "snapToEnd offset should be 400 (600 - 200), got: " .. tostring(offset))
  end

  print("PASS: test_scroll_snap_to_end")
end
