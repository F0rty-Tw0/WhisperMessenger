local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")

-- Every call into the game's prompted bindings the fake records.
local PROMPT_CALLS = { "CreatePromptedBinding", "CreatePromptedBindingFooter", "ShowAndActivateBindings", "HideAndDeactivateBindings" }

local function make()
  local env = FakeGamepad.New()
  local frame = FakeUI.NewFactory().CreateFrame("Frame", "WhisperMessengerWindow", nil)
  return env, frame, GamepadNav.New(frame, env.deps())
end

local function promptCalls(env)
  local names = {}
  for _, call in ipairs(env.calls) do
    for _, name in ipairs(PROMPT_CALLS) do
      if call.name == name then
        names[#names + 1] = name
      end
    end
  end
  return table.concat(names, ",")
end

return function()
  -- test_show_hide_show_never_calls_the_prompted_bindings
  do
    local env, _, nav = make()
    nav.onShow()
    nav.onHide()
    nav.onShow()
    assert(promptCalls(env) == "", "no prompted-binding call; got " .. promptCalls(env))
  end

  -- test_combat_round_never_calls_the_prompted_bindings
  do
    local env, _, nav = make()
    env.combat = true
    nav.onShow()
    env.combat = false
    env.regen()
    assert(env.count("FrameShown") == 1, "the window registers once combat ends")
    assert(promptCalls(env) == "", "no prompted-binding call; got " .. promptCalls(env))
  end

  -- test_hide_in_combat_never_calls_the_prompted_bindings
  do
    local env, _, nav = make()
    nav.onShow()
    env.combat = true
    nav.onHide()
    env.combat = false
    env.regen()
    assert(env.count("FrameHidden") == 1, "the hide settles once combat ends")
    assert(promptCalls(env) == "", "no prompted-binding call; got " .. promptCalls(env))
  end

  -- test_nav_has_no_right_click_binding
  do
    local _, _, nav = make()
    assert(nav.isActive() and nav.bindRightClick == nil, "X has no binding, so nothing tags frames for it")
  end
end
