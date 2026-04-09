local ScrollView = require("WhisperMessenger.UI.ScrollView")
local Metrics = require("WhisperMessenger.UI.ScrollView.Metrics")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  -- Scenario: small content (2 messages worth), large viewport -> scrollBar hidden
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent.height = 400
    parent.width = 300

    local view = ScrollView.Create(factory, parent, { width = 300, height = 400 })
    ScrollView.RefreshMetrics(view, 150, true)

    assert(
      view.scrollBar.shown == false,
      "small content: scrollBar should be hidden. shown=" .. tostring(view.scrollBar.shown)
    )
  end

  -- Scenario: shrink after previous overflow -> scrollBar should re-hide
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent.height = 400
    parent.width = 300

    local view = ScrollView.Create(factory, parent, { width = 300, height = 400 })
    ScrollView.RefreshMetrics(view, 800, true)
    assert(view.scrollBar.shown == true, "phase1: large content should show scrollBar")

    ScrollView.RefreshMetrics(view, 120, true)
    assert(
      view.scrollBar.shown == false,
      "phase2: after shrink to 120, scrollBar should hide. shown=" .. tostring(view.scrollBar.shown)
    )
  end

  -- Scenario: stale WoW GetVerticalScrollRange (returns cached old positive value).
  -- Our manual fallback should kick in and correctly report range=0 when content <= viewport.
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    parent.height = 400
    parent.width = 300

    local view = ScrollView.Create(factory, parent, { width = 300, height = 400 })

    -- Pre-populate with large content
    ScrollView.RefreshMetrics(view, 800, true)

    -- Monkey-patch: WoW reports stale 600 even after content is shrunk
    view.scrollFrame.GetVerticalScrollRange = function()
      return 600
    end

    -- Shrink content
    ScrollView.RefreshMetrics(view, 120, true)

    local range = Metrics.GetRange(view)
    assert(
      range == 0,
      "stale WoW range: GetRange should report 0 when content (120) <= viewport (400), got " .. tostring(range)
    )
    assert(
      view.scrollBar.shown == false,
      "stale WoW range: scrollBar should hide. shown=" .. tostring(view.scrollBar.shown)
    )
  end

  print("PASS: test_scroll_no_overflow")
end
