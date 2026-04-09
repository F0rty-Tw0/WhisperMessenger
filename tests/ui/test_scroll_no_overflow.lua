local ScrollView = require("WhisperMessenger.UI.ScrollView")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  -- Regression: small content (2 messages worth) in a large viewport
  -- must hide the scrollBar.
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

  -- Regression: shrinking content back below the viewport must re-hide the
  -- scrollBar (covers conversation-switch from a long chat to a short one).
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

  print("PASS: test_scroll_no_overflow")
end
