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

  -- test_jump_target_hands_smartnav_a_frame
  do
    local env, _, nav = setup()
    local a, b = {}, {}
    nav.setJumpTarget(a, "RIGHT", b)
    local call = env.calls[1]
    assert(call ~= nil, "a call was made")
    local args = call.args
    assert(env.count("AddJumpNavigationOverride") == 1 and args[1] == a and args[2].dirKey == "right" and args[3] == b, "frame target")
  end

  -- test_same_target_is_set_once
  do
    local env, _, nav = setup()
    local a, b = {}, {}
    nav.setJumpTarget(a, "RIGHT", b)
    nav.setJumpTarget(a, "RIGHT", b)
    assert(env.count("AddJumpNavigationOverride") == 1, "memo: no second call")
  end

  -- test_new_target_replaces_the_old
  do
    local env, _, nav = setup()
    local a, b, c = {}, {}, {}
    nav.setJumpTarget(a, "RIGHT", b)
    nav.setJumpTarget(a, "RIGHT", c)
    assert(env.count("AddJumpNavigationOverride") == 2 and env.overrideFor(a, "RIGHT") == c, "retargeted")
  end

  -- test_each_direction_keeps_its_own_target
  do
    local env, _, nav = setup()
    local a, b = {}, {}
    nav.setJumpTarget(a, "RIGHT", b)
    nav.setJumpTarget(a, "LEFT", b)
    assert(env.count("AddJumpNavigationOverride") == 2 and env.overrideFor(a, "LEFT") == b, "per direction")
  end

  -- test_nil_clears_a_set_target
  do
    local env, _, nav = setup()
    local a, b, c = {}, {}, {}
    nav.setJumpTarget(a, "RIGHT", b)
    nav.setJumpTarget(a, "RIGHT", c)
    nav.setJumpTarget(a, "RIGHT", nil)
    local third = env.calls[3]
    assert(third ~= nil, "a third call was made")
    assert(env.count("AddJumpNavigationOverride") == 3 and third.args[3] == nil and env.overrideFor(a, "RIGHT") == nil, "cleared with nil")
    nav.setJumpTarget(a, "RIGHT", nil)
    assert(env.count("AddJumpNavigationOverride") == 3, "already clear: no call")
  end

  -- test_nil_on_an_unset_widget_does_nothing
  do
    local env, _, nav = setup()
    nav.setJumpTarget({}, "LEFT", nil)
    assert(#env.calls == 0, "nothing to clear")
  end

  -- test_jump_target_in_combat_settles_the_last_target_in_order
  do
    local env, _, nav = setup()
    local a, b, c = {}, {}, {}
    nav.onShow()
    env.combat = true
    nav.setJumpTarget(a, "RIGHT", b)
    nav.setJumpTarget(a, "RIGHT", c)
    assert(env.count("AddJumpNavigationOverride") == 0, "none in combat")
    endCombat(env)
    assert(env.count("AddJumpNavigationOverride") == 2, "both settled, in call order")
    assert(env.overrideFor(a, "RIGHT") == c, "last target wins after regen")
  end

  -- test_jump_target_needs_the_game_functions
  for _, overrides in ipairs({ { smartNavigation = false }, { addJumpOverride = false }, { directions = false } }) do
    local env, _, nav = setup(overrides)
    nav.setJumpTarget({}, "LEFT", {})
    assert(#env.calls == 0, "no override without the game's functions")
  end

  -- test_function_target_is_refused
  do
    local env, _, nav = setup()
    local ok, err = pcall(nav.setJumpTarget, {}, "LEFT", function() end)
    assert(not ok and tostring(err):find("frame or nil", 1, true), "refused")
    assert(env.count("AddJumpNavigationOverride") == 0, "no call")
  end

  -- test_no_function_override_marks_are_left
  do
    local _, _, nav = setup()
    assert(nav.setStepper == nil and nav.setEdgeOverride == nil, "active nav")
    local _, _, inert = setup({ gamepadMode = false })
    assert(inert.setStepper == nil and inert.setEdgeOverride == nil and type(inert.setJumpTarget) == "function", "inert nav")
  end

  -- test_fake_smartnav_rejects_function_overrides
  do
    local env = FakeGamepad.New()
    assert(not pcall(env.addJumpOverride, {}, env.directions.LEFT, function() end), "fake raises on a function")
  end
end
