local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")

local CTX = "WhisperMessenger_RightClick"

local function make(overrides)
  local env = FakeGamepad.New()
  local frame = FakeUI.NewFactory().CreateFrame("Frame", "WhisperMessengerWindow", nil)
  return env, frame, GamepadNav.New(frame, env.deps(overrides))
end

return function()
  -- test_right_click_context_is_the_addon_wide_value
  do
    assert(GamepadNav.RIGHT_CLICK_CONTEXT == CTX, "one context value for rows, header and bubbles")
  end

  -- test_bind_waits_for_registration_then_builds_one_x_binding
  do
    local env, frame, nav = make()
    nav.bindRightClick(CTX, "Options")
    assert(env.count("CreatePromptedBinding") == 0, "nothing built before the window registers")
    nav.onShow()
    assert(#env.bindings == 1, "one binding")
    local b = env.bindings[1]
    assert(b.key == env.FACE_LEFT and b.label == "Options", "X with the given label")
    assert(#b.contexts == 1 and b.contexts[1] == CTX, "usable only on targets with our context")
    assert(b.visibility == env.ONLY_IF_USABLE, "X stays free when no target with our context is focused")
    local f = env.footers[1]
    assert(f.parent == frame and f.finalized and f.shown and f.bindings[1] == b, "footer on the window, finalized, shown")
  end

  -- test_hide_deactivates_and_reshow_reuses_the_binding
  do
    local env, _, nav = make()
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    nav.onHide()
    assert(env.count("HideAndDeactivateBindings") == 1 and not env.footers[1].shown, "hidden with the window")
    nav.onShow()
    assert(env.count("CreatePromptedBinding") == 1 and env.count("ShowAndActivateBindings") == 2, "built once, shown again")
  end

  -- test_bind_while_registered_shows_at_once
  do
    local env, _, nav = make()
    nav.onShow()
    nav.bindRightClick(CTX, "Options")
    assert(env.footers[1] and env.footers[1].shown, "registered and out of combat: shown now")
  end

  -- test_second_bind_is_ignored
  do
    local env, _, nav = make()
    nav.bindRightClick(CTX, "Options")
    nav.bindRightClick("Other", "Other")
    nav.onShow()
    assert(#env.bindings == 1 and env.bindings[1].contexts[1] == CTX, "first call wins")
  end

  -- test_x_right_clicks_only_targets_with_the_context
  do
    local env, _, nav = make()
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    local factory = FakeUI.NewFactory()
    local tagged, plain = factory.CreateFrame("Button", nil, nil), factory.CreateFrame("Button", nil, nil)
    local got = {}
    tagged:SetScript("OnClick", function(_self, button)
      got[#got + 1] = button
    end)
    tagged.buttonContext = CTX
    assert(env.pressX(tagged) == true and got[1] == "RightButton", "X right-clicks a tagged target")
    assert(env.pressX(plain) == false and env.count("RightClick") == 1, "X does nothing on an untagged target")
  end

  -- test_bind_in_combat_waits_for_regen
  do
    local env, _, nav = make()
    nav.onShow()
    env.combat = true
    nav.bindRightClick(CTX, "Options")
    assert(env.count("CreatePromptedBinding") == 0, "no game call in combat")
    env.combat = false
    env.regen()
    assert(#env.bindings == 1 and env.footers[1].shown, "built and shown once combat ends")
  end

  -- test_hide_in_combat_deactivates_on_regen
  do
    local env, _, nav = make()
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    env.combat = true
    nav.onHide()
    assert(env.count("HideAndDeactivateBindings") == 0, "no game call in combat")
    env.combat = false
    env.regen()
    assert(env.count("HideAndDeactivateBindings") == 1, "deactivated with the settled FrameHidden")
  end

  -- test_combat_start_deactivates_the_footer
  do
    local env, _, nav = make()
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    env.regenDisabled()
    assert(env.count("HideAndDeactivateBindings") == 1 and not env.footers[1].shown, "footer off before lockdown")
    env.combat = true
    assert(env.count("ShowAndActivateBindings") == 1, "nothing re-activates during combat")
    env.combat = false
    env.regen()
    assert(env.count("ShowAndActivateBindings") == 2 and env.footers[1].shown, "footer back on after combat")
    local names = {}
    for _, c in ipairs(env.calls) do
      if c.name == "HideAndDeactivateBindings" or c.name == "ShowAndActivateBindings" then
        names[#names + 1] = c.name
      end
    end
    assert(
      table.concat(names, ",") == "ShowAndActivateBindings,HideAndDeactivateBindings,ShowAndActivateBindings",
      "hide on regen-disabled, show after regen"
    )
  end

  -- test_combat_start_on_a_hidden_window_keeps_it_off
  do
    local env, _, nav = make()
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    nav.onHide()
    env.regenDisabled()
    env.regen()
    assert(env.count("ShowAndActivateBindings") == 1 and not env.footers[1].shown, "unregistered: regen shows nothing")
  end

  -- test_shown_in_mouse_mode_builds_nothing
  do
    local env, _, nav = make()
    env.shownResults = { "nil" }
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    env.regenDisabled()
    assert(env.count("CreatePromptedBinding") == 0, "unregistered: no footer, and combat start has none to hide")
  end

  -- test_regen_without_combat_start_does_not_reactivate
  do
    local env, _, nav = make()
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    env.regen()
    nav.onHide()
    env.regenDisabled()
    assert(env.count("ShowAndActivateBindings") == 1 and env.count("HideAndDeactivateBindings") == 1, "each switch once")
  end

  -- test_shared_utility_without_the_binding_api_does_nothing
  do
    local env, _, nav = make({ gamepadSharedUtility = {} })
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    assert(#env.bindings == 0 and env.count("FrameShown") == 1, "partial API: no X, no error")
  end

  -- test_off_forever_bind_touches_nothing
  do
    local env, _, nav = make({ isForever = false })
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    assert(#env.calls == 0, "inert nav")
  end

  -- test_without_shared_utility_bind_does_nothing
  do
    local env, _, nav = make({ gamepadSharedUtility = false })
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    assert(env.count("CreatePromptedBinding") == 0 and env.count("FrameShown") == 1, "window still registers; no X")
  end

  -- test_without_visibility_types_x_still_binds
  do
    local env, _, nav = make({ promptedBindingMixin = false })
    nav.bindRightClick(CTX, "Options")
    nav.onShow()
    assert(#env.bindings == 1 and env.bindings[1].contexts[1] == CTX, "older client: still bound")
    -- PromptedBinding.lua#L79, #L464: a nil visibility type is not "default".
    assert(env.bindings[1].visibility == env.promptedBindingMixin.VISIBILITY_TYPE.ALWAYS, "visibility left at its default")
  end
end
