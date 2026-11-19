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

  -- test_new_marks_off_forever_touch_nothing
  for _, overrides in ipairs({ { isForever = false }, { gamepadMode = false } }) do
    local env, _, nav = setup(overrides)
    nav.markFocusable({})
    assert(#env.calls == 0, "inert off Forever")
  end

  -- test_marks_default_to_the_game_globals
  do
    local env = FakeGamepad.New()
    local frame = FakeUI.NewFactory().CreateFrame("Frame", "WhisperMessengerWindow", nil)
    env.install()
    local ok, err = pcall(function()
      local nav = GamepadNav.New(frame, { isForever = true, after = env.after, createFrame = env.createFrame })
      nav.markFocusable({})
      assert(names(env) == "MarkFrameFocusable", "defaults read _G")
    end)
    env.uninstall()
    assert(ok, err)
  end
end
