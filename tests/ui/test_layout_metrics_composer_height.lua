local LayoutBuilder = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder")
local Metrics = require("WhisperMessenger.UI.MessengerWindow.LayoutBuilder.Metrics")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local factory = FakeUI.NewFactory()
  local contactsH = 560 - Theme.TOP_BAR_HEIGHT -- 536

  -- test_metrics_without_a_composer_height_use_the_one_row_bar
  do
    local m = Metrics.CalculateRelayout({}, 900, 560, 300, Theme)
    assert(m.composerHeight == 44, "nil height reads as 44, got " .. tostring(m.composerHeight))
    assert(m.threadHeight == contactsH - 44 - 1, "thread height as today, got " .. tostring(m.threadHeight))
  end

  -- test_metrics_take_the_thread_height_from_the_composer_height
  do
    local m = Metrics.CalculateRelayout({ composerHeight = 68 }, 900, 560, 300, Theme)
    assert(m.threadHeight == contactsH - 68 - 1, "thread shrinks by the bar, got " .. tostring(m.threadHeight))
  end

  -- test_relayout_sizes_the_composer_pane_and_thread_from_the_height
  do
    local host = factory.CreateFrame("Frame", nil, nil)
    local layout = LayoutBuilder.Build(factory, host, { width = 900, height = 560 }, { contactsWidth = 300 })
    layout.composerHeight = 68
    local result = LayoutBuilder.Relayout(layout, 900, 560, 300)
    assert(layout.composerPane.height == 68, "pane is 68 tall, got " .. tostring(layout.composerPane.height))
    assert(layout.threadPane.height == contactsH - 68 - 1, "thread pane follows, got " .. tostring(layout.threadPane.height))
    assert(result.contentHeight == contactsH, "relayout reports the content height, got " .. tostring(result.contentHeight))
  end
end
