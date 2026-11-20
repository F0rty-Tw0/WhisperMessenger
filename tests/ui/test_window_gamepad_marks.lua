local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")

local function setup(overrides)
  local env = FakeGamepad.New()
  local frame = FakeUI.NewFactory().CreateFrame("Frame", "WhisperMessengerWindow", nil)
  return env, frame, GamepadNav.New(frame, env.deps(overrides))
end

local function names(env)
  local out = {}
  for _, c in ipairs(env.calls) do
    table.insert(out, c.name)
  end
  return table.concat(out, ",")
end

local function endCombat(env)
  env.combat = false
  env.regen()
  env.flush()
end

return function()
  -- test_mark_focusable_marks_each_widget_once
  do
    local env, _, nav = setup()
    local slider = {}
    nav.markFocusable(slider)
    nav.markFocusable(slider)
    nav.markFocusable(nil)
    assert(env.count("MarkFrameFocusable") == 1 and env.calls[1].args[1] == slider, "once per widget")
  end

  -- test_each_mark_kind_is_remembered_on_its_own
  do
    local env, _, nav = setup()
    local widget = {}
    nav.ignore(widget)
    nav.markFocusable(widget)
    assert(names(env) == "MarkFrameIgnored,MarkFrameFocusable", "an ignored widget can still be marked focusable")
  end

  -- test_marks_in_combat_settle_once_in_call_order
  do
    local env, _, nav = setup()
    nav.onShow()
    env.combat = true
    local grip, slider, toggle = {}, {}, {}
    nav.ignore(grip, true)
    nav.markFocusable(slider)
    nav.markFocusable(toggle)
    nav.markFocusable(slider)
    assert(names(env) == "FrameShown", "no mark in combat")
    endCombat(env)
    env.regen()
    assert(names(env) == "FrameShown,MarkFrameIgnored,MarkFrameFocusable,MarkFrameFocusable", "settled once, in call order")
    assert(env.calls[3].args[1] == slider and env.calls[4].args[1] == toggle, "call order kept")
    assert(env.calls[2].args[2] == true, "dontPropagate kept through the queue")
  end

  -- test_queued_marks_settle_before_the_rescan
  do
    local env, _, nav = setup()
    nav.onShow()
    env.combat = true
    nav.markFocusable({})
    nav.refresh()
    endCombat(env)
    assert(names(env) == "FrameShown,MarkFrameFocusable,RefreshButtonGroups", "marks before the final re-scan")
  end

  -- test_missing_mark_functions_do_nothing
  do
    local env, _, nav = setup({ markFocusable = false })
    nav.markFocusable({})
    assert(#env.calls == 0, "absent game function: no call, no error")
  end

  -- test_new_marks_without_the_api_touch_nothing
  for _, overrides in ipairs({ { smartNavigation = false }, { gamepadMode = false } }) do
    local env, _, nav = setup(overrides)
    nav.markFocusable({})
    assert(#env.calls == 0, "inert without the gamepad UI API")
  end

  -- test_marks_default_to_the_game_globals
  do
    local env = FakeGamepad.New()
    local frame = FakeUI.NewFactory().CreateFrame("Frame", "WhisperMessengerWindow", nil)
    env.install()
    local ok, err = pcall(function()
      local nav = GamepadNav.New(frame, { after = env.after, createFrame = env.createFrame })
      nav.markFocusable({})
      assert(names(env) == "MarkFrameFocusable", "defaults read _G")
    end)
    env.uninstall()
    assert(ok, err)
  end

  -- test_set_stepper_installs_left_and_right_once
  do
    local env, _, nav = setup()
    local slider = {}
    nav.setStepper(slider, function() end)
    nav.setStepper(slider, function() end)
    assert(env.count("AddJumpNavigationOverride") == 2, "LEFT and RIGHT, once per widget")
    local keys = { env.calls[1].args[2].dirKey, env.calls[2].args[2].dirKey }
    table.sort(keys)
    assert(keys[1] == "left" and keys[2] == "right" and env.calls[1].args[1] == slider, "on the slider, left and right")
    assert(type(env.calls[1].args[3]) == "function", "a function override, not a frame")
  end

  -- test_left_and_right_step_and_keep_focus
  do
    local env, _, nav = setup()
    local slider, deltas = {}, {}
    nav.setStepper(slider, function(delta)
      table.insert(deltas, delta)
    end)
    assert(env.press(slider, "RIGHT") == "stay" and env.press(slider, "LEFT") == "stay", "focus stays on the slider")
    assert(table.concat(deltas, ",") == "1,-1", "right +1, left -1")
  end

  -- test_step_at_the_limit_still_keeps_focus
  do
    local env, _, nav = setup()
    local slider, value = {}, 10
    nav.setStepper(slider, function(delta)
      value = math.min(10, value + delta)
      return false
    end)
    assert(env.press(slider, "RIGHT") == "stay" and value == 10, "at max: no change, no jump to the next column")
  end

  -- test_up_and_down_leave_the_stepper
  do
    local env, _, nav = setup()
    local slider, steps = {}, 0
    nav.setStepper(slider, function()
      steps = steps + 1
    end)
    assert(env.press(slider, "UP") == "move" and env.press(slider, "DOWN") == "move" and steps == 0, "up/down navigate")
  end

  -- test_slider_can_be_focusable_and_a_stepper
  do
    local env, _, nav = setup()
    local slider = {}
    nav.markFocusable(slider)
    nav.setStepper(slider, function() end)
    assert(env.count("MarkFrameFocusable") == 1 and env.count("AddJumpNavigationOverride") == 2, "both marks apply")
  end

  -- test_set_stepper_in_combat_installs_once_after_regen
  do
    local env, _, nav = setup()
    local slider, steps = {}, 0
    nav.onShow()
    env.combat = true
    nav.setStepper(slider, function()
      steps = steps + 1
    end)
    nav.setStepper(slider, function() end)
    assert(env.count("AddJumpNavigationOverride") == 0, "no override in combat")
    endCombat(env)
    assert(env.count("AddJumpNavigationOverride") == 2, "installed once after regen")
    assert(env.press(slider, "RIGHT") == "stay" and steps == 1, "the first step function is the one installed")
  end

  -- test_stepper_needs_the_game_functions
  for _, overrides in ipairs({ { smartNavigation = false }, { addJumpOverride = false }, { directions = false } }) do
    local env, _, nav = setup(overrides)
    nav.setStepper({}, function() end)
    assert(#env.calls == 0, "no override without the game's functions")
  end

  -- test_edge_override_stays_when_on_press_returns_true
  do
    local env, _, nav = setup()
    local row, presses = {}, 0
    nav.setEdgeOverride(row, "DOWN", function()
      presses = presses + 1
      return true
    end)
    assert(env.count("AddJumpNavigationOverride") == 1 and env.calls[1].args[2].dirKey == "down", "one DOWN override")
    assert(env.press(row, "DOWN") == "stay" and presses == 1, "handled: focus stays")
    assert(env.press(row, "UP") == "move" and presses == 1, "the other direction is untouched")
  end

  -- test_edge_override_moves_when_on_press_returns_nil
  do
    local env, _, nav = setup()
    local row = {}
    nav.setEdgeOverride(row, "UP", function() end)
    assert(env.press(row, "UP") == "move", "not handled: SmartNav moves as usual")
  end

  -- test_edge_override_once_per_widget_and_direction
  do
    local env, _, nav = setup()
    local row = {}
    nav.setStepper(row, function() end)
    nav.setEdgeOverride(row, "DOWN", function() end)
    nav.setEdgeOverride(row, "DOWN", function() end)
    nav.setEdgeOverride(row, "UP", function() end)
    assert(env.count("AddJumpNavigationOverride") == 4, "LEFT, RIGHT, DOWN, UP: each once")
  end

  -- test_edge_override_in_combat_settles_once_with_the_stepper_queue
  do
    local env, _, nav = setup()
    local slider, row = {}, {}
    nav.onShow()
    env.combat = true
    nav.setStepper(slider, function() end)
    nav.setEdgeOverride(row, "DOWN", function()
      return true
    end)
    nav.setEdgeOverride(row, "DOWN", function() end)
    assert(env.count("AddJumpNavigationOverride") == 0, "no override in combat")
    endCombat(env)
    env.regen()
    assert(env.count("AddJumpNavigationOverride") == 3, "settled once")
    assert(env.calls[4].args[1] == row and env.calls[4].args[2].dirKey == "down", "in call order, after the stepper's two")
    assert(env.press(row, "DOWN") == "stay", "the first onPress is the one installed")
  end

  -- test_edge_override_needs_the_game_functions
  for _, overrides in ipairs({ { smartNavigation = false }, { addJumpOverride = false }, { directions = false } }) do
    local env, _, nav = setup(overrides)
    nav.setEdgeOverride({}, "DOWN", function()
      return true
    end)
    assert(#env.calls == 0, "no override without the game's functions")
  end
end
