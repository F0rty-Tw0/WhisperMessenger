local Env = require("tests.helpers.composer_send_focus_env")

local newEnv = Env.NewEnv

return function()
  local savedUIParent = _G.UIParent

  -- test_after_send_clears_focus_in_combat
  do
    local env = newEnv()
    env.startCombat()
    env.input:SetFocus()
    env.focus.afterSend()
    assert(env.input._hasFocus == false, "combat blocks bindings, not focus: a send still clears it")
  end

  -- test_open_window_keeps_key_through_combat
  do
    local env = newEnv()
    env.startCombat()
    assert(#env.bound == 1, "the override must stay for the fight so Enter still reaches the composer")
  end

  -- test_no_binding_calls_in_combat
  do
    local env = newEnv()
    env.startCombat()
    env.focus.sync()
    env.pane:Hide()
    env.pane:Show()
    env.fire("UPDATE_BINDINGS")
    env.fire("PLAYER_ENTERING_WORLD")
    assert(env.blocked == 0, "bindings can't change in combat")
    assert(#env.bound == 1, "the override is left as it was at the start of the fight")
  end

  -- test_window_closed_at_combat_start_binds_nothing_through_combat
  do
    local env = newEnv()
    env.window:Hide()
    env.focus.sync() -- the game fires the pane's OnHide; the fake doesn't
    env.startCombat()
    env.window:Show()
    env.fire("UPDATE_BINDINGS")
    env.fire("PLAYER_ENTERING_WORLD")
    assert(#env.bound == 0 and env.blocked == 0, "a window opened mid-fight can't bind: Enter stays the game's chat")
  end

  -- test_open_window_with_hidden_composer_binds_at_combat_start
  do
    local env = newEnv()
    env.pane:Hide()
    env.startCombat()
    assert(#env.bound == 1 and env.blocked == 0, "settings or the contact list hide the composer: the open window still keeps Enter")
  end

  -- test_window_hidden_on_combat_start_after_binding_gives_key_back
  do
    local env = newEnv()
    env.pane:Hide()
    env.fire("PLAYER_REGEN_DISABLED")
    env.window:Hide() -- hide-on-combat runs after us; the hidden pane gets no OnHide
    env.combat = true
    assert(#env.bound == 0 and env.blocked == 0, "a window hidden as combat starts leaves Enter the game's chat")
  end

  -- test_open_window_with_disabled_composer_binds_at_combat_start
  do
    local env = newEnv()
    env.enabled = false
    env.focus.sync()
    env.startCombat()
    assert(#env.bound == 1, "no conversation selected: the open window still keeps Enter for the fight")
  end

  -- test_setting_off_binds_nothing_at_combat_start
  do
    local env = newEnv({ on = false })
    env.startCombat()
    assert(#env.bound == 0, "the setting is off: Enter stays the game's chat in combat")
  end

  -- test_combat_start_event_in_lockdown_makes_no_binding_calls
  do
    local env = newEnv()
    env.pane:Hide()
    env.combat = true
    env.fire("PLAYER_REGEN_DISABLED")
    assert(env.blocked == 0 and #env.bound == 0, "bindings can't change once lockdown has begun")
  end

  -- test_combat_click_with_hidden_composer_does_nothing
  do
    local env = newEnv()
    env.pane:Hide()
    env.startCombat()
    env.window.mouseOver = true
    env.button:GetScript("OnClick")(env.button)
    assert(env.input._hasFocus ~= true, "a hidden composer swallows Enter in combat")
  end

  -- test_combat_end_releases_key_bound_for_hidden_composer
  do
    local env = newEnv()
    env.pane:Hide()
    env.startCombat()
    env.endCombat()
    assert(#env.bound == 0, "the composer is still hidden after the fight: the key goes back")
  end

  -- test_combat_click_focuses_when_mouse_over_window
  do
    local env = newEnv()
    env.startCombat()
    env.window.mouseOver = true
    env.button:GetScript("OnClick")(env.button)
    assert(env.input._hasFocus == true, "in combat, Enter focuses the composer while the mouse is over the window")
  end

  -- test_combat_click_ignored_when_mouse_not_over_window
  do
    local env = newEnv()
    env.startCombat()
    env.window.mouseOver = false
    env.button:GetScript("OnClick")(env.button)
    assert(env.input._hasFocus ~= true, "in combat, Enter does nothing while the mouse is off the window")
  end

  -- test_combat_click_ignored_when_window_closed_mid_fight
  do
    local env = newEnv()
    env.startCombat()
    env.window.mouseOver = true
    env.pane:Hide()
    env.button:GetScript("OnClick")(env.button)
    assert(env.input._hasFocus ~= true, "a hidden composer never takes the cursor")
  end

  -- test_combat_click_ignored_when_setting_off_or_composer_disabled
  do
    local env = newEnv()
    env.startCombat()
    env.window.mouseOver = true
    env.on = false
    env.button:GetScript("OnClick")(env.button)
    assert(env.input._hasFocus ~= true, "setting turned off in combat: no focus")
    env.on = true
    env.enabled = false
    env.button:GetScript("OnClick")(env.button)
    assert(env.input._hasFocus ~= true, "disabled composer in combat: no focus")
  end

  -- test_click_out_of_combat_ignores_mouse_position
  do
    local env = newEnv()
    env.window.mouseOver = false
    env.button:GetScript("OnClick")(env.button)
    assert(env.input._hasFocus == true, "out of combat the mouse position does not matter")
  end

  -- test_combat_end_releases_key_closed_mid_fight
  do
    local env = newEnv()
    env.startCombat()
    env.pane:Hide()
    env.endCombat()
    assert(#env.bound == 0, "the override left by a window closed mid-fight is released after combat")
  end

  -- test_combat_end_rebinds_when_eligible
  do
    local env = newEnv()
    env.window:Hide()
    env.focus.sync() -- the game fires the pane's OnHide; the fake doesn't
    env.startCombat()
    env.window:Show()
    env.endCombat()
    assert(#env.bound == 1, "a window opened mid-fight takes the key after combat")
  end

  -- test_disabled_during_combat_released_after
  do
    local env = newEnv()
    env.startCombat()
    env.enabled = false
    env.endCombat()
    assert(#env.bound == 0, "a composer disabled in combat gives the key back after it")
  end

  -- test_keys_changed_in_combat_bind_after
  do
    local env = newEnv()
    env.startCombat()
    env.keys = { "F1" }
    env.fire("UPDATE_BINDINGS")
    env.endCombat()
    assert(#env.bound == 1 and env.bound[1] == "F1", "the new key is bound after combat")
  end

  _G.UIParent = savedUIParent
end
