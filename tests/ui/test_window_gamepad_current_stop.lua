local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")

local function setup(overrides)
  local env = FakeGamepad.New()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", nil)
  frame:Show()
  local stop = factory.CreateFrame("Button", nil, frame)
  stop:Show()
  local nav = GamepadNav.New(frame, env.deps(overrides))
  return env, frame, stop, nav
end

-- The window registered with the game and stop focused in it.
local function focused(overrides)
  local env, frame, stop, nav = setup(overrides)
  nav.onShow()
  env.focus(stop, frame)
  return env, frame, stop, nav
end

return function()
  -- test_current_stop_is_the_focused_button
  do
    local _, _, stop, nav = focused()
    assert(nav.currentStop() == stop, "the game's focused button in our window")
  end

  -- test_no_current_stop_before_the_window_registers
  do
    local env, frame, stop, nav = setup()
    env.focus(stop, frame)
    assert(nav.currentStop() == nil, "not registered, no stop")
  end

  -- test_no_current_stop_in_combat
  do
    local env, _, _, nav = focused()
    env.combat = true
    assert(nav.currentStop() == nil, "nothing in combat")
  end

  -- test_no_current_stop_while_a_popup_is_active
  do
    local env, _, stop, nav = focused()
    env.focus(stop, {})
    assert(nav.currentStop() == nil, "another frame is active")
  end

  -- test_no_current_stop_when_the_button_is_hidden
  do
    local _, _, stop, nav = focused()
    stop:Hide()
    assert(nav.currentStop() == nil, "the game keeps a hidden button as current")
  end

  -- test_no_current_stop_when_nothing_is_focused
  do
    local env, frame, _, nav = focused()
    env.focus(nil, frame)
    assert(nav.currentStop() == nil, "no focused button")
  end

  -- test_no_current_stop_without_the_games_getters
  do
    local env, _, _, nav = focused()
    env.smartNavigation.GetCurrentButton = nil
    local ok, stop = pcall(nav.currentStop)
    assert(ok and stop == nil, "no GetCurrentButton, no stop")
  end
  do
    local env, _, _, nav = focused()
    env.smartNavigation.GetActiveFrame = nil
    local ok, stop = pcall(nav.currentStop)
    assert(ok and stop == nil, "no GetActiveFrame, no stop")
  end

  -- test_inert_nav_has_no_current_stop
  do
    local _, _, _, nav = focused({ gamepadMode = false })
    assert(nav.currentStop() == nil, "a client without the gamepad UI has no stop")
  end
end
