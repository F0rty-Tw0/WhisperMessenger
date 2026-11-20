local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")

local CTX = "WhisperMessenger_RightClick"

-- Every call into the game's prompted bindings the fake records.
local PROMPT_CALLS = { "CreatePromptedBinding", "CreatePromptedBindingFooter", "ShowAndActivateBindings", "HideAndDeactivateBindings" }

local function make(overrides)
  local env = FakeGamepad.New()
  local frame = FakeUI.NewFactory().CreateFrame("Frame", "WhisperMessengerWindow", nil)
  return env, frame, GamepadNav.New(frame, env.deps(overrides))
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
  -- test_right_click_context_is_the_addon_wide_value
  do
    assert(GamepadNav.RIGHT_CLICK_CONTEXT == CTX, "one context value for rows, header and bubbles")
  end

  -- test_bind_then_show_hide_show_never_calls_the_prompted_bindings
  do
    local env, _, nav = make()
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    nav.onHide()
    nav.onShow()
    assert(promptCalls(env) == "", "no prompted-binding call; got " .. promptCalls(env))
  end

  -- test_bind_on_a_shown_window_never_calls_the_prompted_bindings
  do
    local env, _, nav = make()
    nav.onShow()
    nav.bindRightClick(CTX, "Options")
    assert(promptCalls(env) == "", "no prompted-binding call; got " .. promptCalls(env))
  end

  -- test_combat_round_never_calls_the_prompted_bindings
  do
    local env, _, nav = make()
    nav.bindRightClick(CTX, "Options")
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
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    env.combat = true
    nav.onHide()
    env.combat = false
    env.regen()
    assert(env.count("FrameHidden") == 1, "the hide settles once combat ends")
    assert(promptCalls(env) == "", "no prompted-binding call; got " .. promptCalls(env))
  end

  -- test_x_on_a_tagged_target_does_nothing
  do
    local env, _, nav = make()
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    local tagged = FakeUI.NewFactory().CreateFrame("Button", nil, nil)
    local clicks = 0
    tagged:SetScript("OnClick", function()
      clicks = clicks + 1
    end)
    tagged.buttonContext = CTX
    assert(env.pressX(tagged) == false and clicks == 0, "X is unbound: no right-click on the target")
  end

  -- test_bind_on_an_active_nav_can_be_called_again
  do
    local _, _, nav = make()
    assert(nav.isActive() and type(nav.bindRightClick) == "function", "callers keep calling it")
    nav.bindRightClick(CTX, "Options")
    nav.bindRightClick("Other", "Other")
  end

  -- test_bind_on_the_inert_nav_touches_nothing
  do
    local env, _, nav = make({ gamepadMode = false })
    assert(not nav.isActive() and type(nav.bindRightClick) == "function", "callers keep calling it")
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    assert(#env.calls == 0, "inert nav")
  end
end
