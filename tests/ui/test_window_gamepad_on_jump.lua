local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")

local function setup(overrides)
  local env = FakeGamepad.New()
  local factory = FakeUI.NewFactory()
  local frame = factory.CreateFrame("Frame", "WhisperMessengerWindow", nil)
  return env, GamepadNav.New(frame, env.deps(overrides)), factory
end

return function()
  -- test_on_jump_reports_the_current_target
  do
    local env, nav = setup()
    local a, b, c = {}, {}, {}
    local got = {}
    nav.onJump(a, "DOWN", function(target)
      got[#got + 1] = target
    end)
    nav.setJumpTarget(a, "DOWN", b)
    env.left(a, "DOWN")
    nav.setJumpTarget(a, "DOWN", c)
    env.left(a, "DOWN")
    assert(#got == 2 and got[1] == b and got[2] == c, "the target at press time")
  end

  -- test_on_jump_is_silent_without_a_target
  do
    local env, nav = setup()
    local a, calls = {}, 0
    nav.onJump(a, "DOWN", function()
      calls = calls + 1
    end)
    env.left(a, "DOWN")
    assert(calls == 0, "spatial move: no jump to report")
  end

  -- test_on_jump_registers_once_per_widget_and_direction
  do
    local env, nav = setup()
    local a = {}
    nav.onJump(a, "DOWN", function() end)
    nav.onJump(a, "DOWN", function() end)
    nav.onJump(a, "UP", function() end)
    assert(env.count("RegisterOutgoingDirNavCallback") == 2, "once per direction")
  end

  -- test_on_jump_in_combat_settles_after
  do
    local env, nav = setup()
    nav.onShow()
    env.combat = true
    nav.onJump({}, "DOWN", function() end)
    assert(env.count("RegisterOutgoingDirNavCallback") == 0, "not in combat")
    env.combat = false
    env.regen()
    assert(env.count("RegisterOutgoingDirNavCallback") == 1, "after combat")
  end

  -- test_on_jump_needs_the_game_functions
  for _, overrides in ipairs({ { gamepadMode = false }, { registerNavCallback = false }, { directions = false } }) do
    local env, nav = setup(overrides)
    nav.onJump({}, "DOWN", function() end)
    assert(#env.calls == 0, "no call without the game's functions")
  end

  -- test_is_stop_follows_the_games_own_rule
  do
    local _, nav, factory = setup()
    local button, plain = factory.CreateFrame("Button", nil, nil), factory.CreateFrame("Frame", nil, nil)
    button:Show()
    plain:Show()
    assert(nav.isStop(button) == true and nav.isStop(plain) == false, "buttons are stops, plain frames are not")
    nav.ignore(button)
    assert(nav.isStop(button) == false, "an ignored button is not")
  end

  -- test_is_stop_needs_the_game_functions
  for _, overrides in ipairs({ { gamepadMode = false }, { canFocus = false }, { isIgnored = false } }) do
    local _, nav, factory = setup(overrides)
    local button = factory.CreateFrame("Button", nil, nil)
    button:Show()
    assert(nav.isStop(button) == false, "no stops without the game's functions")
  end
end
