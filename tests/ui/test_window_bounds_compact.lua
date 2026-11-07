local WindowBounds = require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local L = Theme.LAYOUT

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(1920, 1080)

  -- test_compact_window_is_portrait_by_default
  do
    assert(L.COMPACT_WINDOW_HEIGHT > L.COMPACT_WINDOW_WIDTH, "compact window is taller than wide")
  end

  -- test_compact_window_can_shrink_below_the_normal_minimum
  do
    local minWidth, minHeight = WindowBounds.GetResizeBounds(parent, Theme, 1, false, true)
    assert(minWidth == L.COMPACT_WINDOW_MIN_WIDTH, "compact min width, got " .. tostring(minWidth))
    assert(minHeight == L.COMPACT_WINDOW_MIN_HEIGHT, "compact min height, got " .. tostring(minHeight))
  end

  -- test_clamp_state_keeps_a_narrow_compact_window
  do
    local state = WindowBounds.ClampState(parent, { compactLayout = true, width = L.COMPACT_WINDOW_WIDTH, height = 600 }, Theme, 1)
    assert(state.width == L.COMPACT_WINDOW_WIDTH, "compact width survives the clamp, got " .. tostring(state.width))
  end

  -- test_clamp_state_defaults_a_compact_window_to_compact_size
  do
    local state = WindowBounds.ClampState(parent, { compactLayout = true }, Theme, 1)
    assert(state.width == L.COMPACT_WINDOW_WIDTH, "default compact width, got " .. tostring(state.width))
    assert(state.height == L.COMPACT_WINDOW_HEIGHT, "default compact height, got " .. tostring(state.height))
  end

  -- test_classic_window_keeps_its_minimum
  do
    local state = WindowBounds.ClampState(parent, { width = L.COMPACT_WINDOW_WIDTH, height = 600 }, Theme, 1)
    assert(state.width == L.WINDOW_MIN_WIDTH, "classic window still clamps, got " .. tostring(state.width))
  end
end
