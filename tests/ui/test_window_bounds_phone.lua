local WindowBounds = require("WhisperMessenger.UI.MessengerWindow.WindowBounds")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local L = Theme.LAYOUT

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(1920, 1080)

  -- test_phone_window_is_portrait_by_default
  do
    assert(L.PHONE_WINDOW_HEIGHT > L.PHONE_WINDOW_WIDTH, "phone window is taller than wide")
  end

  -- test_phone_window_can_shrink_below_the_normal_minimum
  do
    local minWidth, minHeight = WindowBounds.GetResizeBounds(parent, Theme, 1, false, true)
    assert(minWidth == L.PHONE_WINDOW_MIN_WIDTH, "phone min width, got " .. tostring(minWidth))
    assert(minHeight == L.PHONE_WINDOW_MIN_HEIGHT, "phone min height, got " .. tostring(minHeight))
  end

  -- test_clamp_state_keeps_a_narrow_phone_window
  do
    local state = WindowBounds.ClampState(parent, { phoneLayout = true, width = L.PHONE_WINDOW_WIDTH, height = 600 }, Theme, 1)
    assert(state.width == L.PHONE_WINDOW_WIDTH, "phone width survives the clamp, got " .. tostring(state.width))
  end

  -- test_clamp_state_defaults_a_phone_window_to_phone_size
  do
    local state = WindowBounds.ClampState(parent, { phoneLayout = true }, Theme, 1)
    assert(state.width == L.PHONE_WINDOW_WIDTH, "default phone width, got " .. tostring(state.width))
    assert(state.height == L.PHONE_WINDOW_HEIGHT, "default phone height, got " .. tostring(state.height))
  end

  -- test_classic_window_keeps_its_minimum
  do
    local state = WindowBounds.ClampState(parent, { width = L.PHONE_WINDOW_WIDTH, height = 600 }, Theme, 1)
    assert(state.width == L.WINDOW_MIN_WIDTH, "classic window still clamps, got " .. tostring(state.width))
  end
end
