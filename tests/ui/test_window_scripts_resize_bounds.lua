local FakeUI = require("tests.helpers.fake_ui")
local ResizeBounds = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.ResizeBounds")
local Theme = require("WhisperMessenger.UI.Theme")

-- Window resizes clamp to the frame's live resize bounds (which drop while
-- the contacts pane is the rail), falling back to the theme minimums.

return function()
  local factory = FakeUI.NewFactory()

  -- test_frame_bounds_win_over_the_theme
  do
    local frame = factory.CreateFrame("Frame", nil, nil)
    frame:SetResizeBounds(387, 320, 1920, 1080)
    local width, height = ResizeBounds.Clamp(frame, Theme, 300, 200)
    assert(width == 387 and height == 320, "clamped to the frame minimum, got " .. width .. "x" .. height)
    width, height = ResizeBounds.Clamp(frame, Theme, 3000, 2000)
    assert(width == 1920 and height == 1080, "clamped to the frame maximum")
  end

  -- test_theme_minimum_without_frame_bounds
  do
    local width = ResizeBounds.Clamp(nil, Theme, 100, 100)
    assert(width == Theme.LAYOUT.WINDOW_MIN_WIDTH, "theme minimum when the frame has no bounds")
  end

  -- test_finite_positive_check
  assert(ResizeBounds.IsPositiveFiniteNumber(1) == true, "1 is positive")
  assert(ResizeBounds.IsPositiveFiniteNumber(0) == false, "0 is not")
  assert(ResizeBounds.IsPositiveFiniteNumber(math.huge) == false, "infinity is not")
  assert(ResizeBounds.IsPositiveFiniteNumber(0 / 0) == false, "NaN is not")
end
