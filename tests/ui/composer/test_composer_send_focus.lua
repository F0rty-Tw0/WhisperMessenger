local FakeUI = require("tests.helpers.fake_ui")
local ComposerSendFocus = require("WhisperMessenger.UI.Composer.ComposerSendFocus")

-- Builds a ComposerSendFocus with recorded binding calls. env.on, env.enabled
-- and env.combat drive its state; env.bound lists the keys bound now, and
-- env.blocked counts binding calls made in combat, which the game refuses.
local function newEnv(overrides)
  local factory = FakeUI.NewFactory()
  local env = { on = true, enabled = true, combat = false, keys = { "ENTER" }, bound = {}, binds = 0, blocked = 0 }
  for key, value in pairs(overrides or {}) do
    env[key] = value
  end
  env.pane = factory.CreateFrame("Frame", nil, nil)
  env.input = factory.CreateFrame("EditBox", nil, env.pane)
  env.focus = ComposerSendFocus.Create(env.pane, env.input, {
    isOn = function()
      return env.on
    end,
    isEnabled = function()
      return env.enabled
    end,
  }, {
    createFrame = function(...)
      env.button = factory.CreateFrame(...)
      function env.button:RegisterForClicks(...)
        self.clickTypes = { ... }
      end
      return env.button
    end,
    getBindingKey = function(action)
      assert(action == "OPENCHAT", "the override follows the open-chat binding")
      return table.unpack(env.keys)
    end,
    inCombat = function()
      return env.combat
    end,
    setOverrideBindingClick = function(owner, priority, key, buttonName)
      if env.combat then
        env.blocked = env.blocked + 1
      end
      assert(priority == true, "the override must beat the game's chat binding")
      assert(owner == env.button, "the override belongs to the module's button")
      env.buttonName = buttonName
      env.binds = env.binds + 1
      table.insert(env.bound, key)
    end,
    clearOverrideBindings = function(owner)
      if env.combat then
        env.blocked = env.blocked + 1
      end
      assert(owner == env.button, "clear only the overrides this button owns")
      env.bound = {}
    end,
  })
  function env.fire(event)
    env.button:GetScript("OnEvent")(env.button, event)
  end
  function env.startCombat()
    env.fire("PLAYER_REGEN_DISABLED")
    env.combat = true
  end
  function env.endCombat()
    env.combat = false
    env.fire("PLAYER_REGEN_ENABLED")
  end
  env.pane:Show()
  return env
end

return function()
  -- test_after_send_clears_focus_when_on
  do
    local env = newEnv()
    env.input:SetFocus()
    env.focus.afterSend()
    assert(env.input._hasFocus == false, "a send must clear focus when the setting is on")
  end

  -- test_after_send_keeps_focus_when_off
  do
    local env = newEnv({ on = false })
    env.input:SetFocus()
    env.focus.afterSend()
    assert(env.input._hasFocus == true, "a send must keep focus when the setting is off")
  end

  -- test_after_send_clears_focus_in_combat
  do
    local env = newEnv()
    env.startCombat()
    env.input:SetFocus()
    env.focus.afterSend()
    assert(env.input._hasFocus == false, "combat blocks bindings, not focus: a send still clears it")
  end

  -- test_binds_every_open_chat_key_while_eligible
  do
    local env = newEnv({ keys = { "ENTER", "NUMPADENTER" } })
    assert(#env.bound == 2 and env.bound[1] == "ENTER" and env.bound[2] == "NUMPADENTER", "every open-chat key must be bound")
    assert(env.buttonName == "WhisperMessengerComposerEnterButton", "the override clicks the named button")
  end

  -- test_button_clicks_on_key_down_only
  do
    local clickTypes = newEnv().button.clickTypes or {}
    assert(#clickTypes == 1 and clickTypes[1] == "AnyDown", "a second click on release would leak into the composer")
  end

  -- test_click_focuses_input
  do
    local env = newEnv()
    env.button:GetScript("OnClick")(env.button)
    assert(env.input._hasFocus == true, "the key must put the cursor in the composer")
  end

  -- test_button_listens_for_its_events
  do
    local env = newEnv()
    for _, event in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "UPDATE_BINDINGS", "PLAYER_ENTERING_WORLD" }) do
      assert(env.button:IsEventRegistered(event), "the button must listen for " .. event)
    end
  end

  -- test_pane_hide_unbinds_and_show_rebinds
  do
    local env = newEnv()
    env.pane:Hide()
    assert(#env.bound == 0, "a hidden composer must give the key back")
    env.pane:Show()
    assert(#env.bound == 1, "a shown composer takes the key again")
  end

  -- test_composer_hidden_by_parent_gives_key_back
  do
    local env = newEnv()
    local parent = FakeUI.NewFactory().CreateFrame("Frame", nil, nil)
    parent:Show()
    env.pane.parent = parent
    parent:Hide()
    env.focus.sync()
    assert(#env.bound == 0, "closing the window hides the pane's parent: the key must go back")
  end

  -- test_toggle_off_leaves_key_unbound_on_show
  do
    local env = newEnv()
    env.pane:Hide()
    env.on = false
    env.pane:Show()
    assert(#env.bound == 0, "turning the setting off must leave the key with the game")
  end

  -- test_toggle_on_binds_on_next_show
  do
    local env = newEnv({ on = false })
    assert(#env.bound == 0, "the setting is off: no override")
    env.pane:Hide()
    env.on = true
    env.pane:Show()
    assert(#env.bound == 1, "turning the setting on takes the key when settings close")
  end

  -- test_disabled_composer_unbinds_and_enabled_rebinds
  do
    local env = newEnv()
    env.enabled = false
    env.focus.sync()
    assert(#env.bound == 0, "a disabled composer must give the key back")
    env.enabled = true
    env.focus.sync()
    assert(#env.bound == 1, "an enabled composer takes the key again")
  end

  -- test_combat_start_unbinds
  do
    local env = newEnv()
    env.fire("PLAYER_REGEN_DISABLED")
    assert(#env.bound == 0, "the key goes back to the game before the lockdown")
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
    assert(#env.bound == 0, "the key stays with the game for the whole fight")
  end

  -- test_combat_end_rebinds_when_eligible
  do
    local env = newEnv()
    env.startCombat()
    env.endCombat()
    assert(#env.bound == 1, "the key comes back after combat")
  end

  -- test_disabled_during_combat_stays_unbound_after
  do
    local env = newEnv()
    env.startCombat()
    env.enabled = false
    env.endCombat()
    assert(#env.bound == 0, "a composer disabled in combat must not take the key after it")
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

  -- test_update_bindings_rebinds_changed_keys
  do
    local env = newEnv()
    env.keys = { "F1" }
    env.fire("UPDATE_BINDINGS")
    assert(#env.bound == 1 and env.bound[1] == "F1", "a rebind must move the override to the new key")
  end

  -- test_update_bindings_same_keys_does_not_rebind
  do
    local env = newEnv()
    local before = env.binds
    env.fire("UPDATE_BINDINGS")
    assert(env.binds == before, "changing an override fires this event too; only a real change rebinds")
  end

  -- test_no_key_bound_means_no_override
  do
    local env = newEnv({ keys = {} })
    assert(env.binds == 0, "no open-chat key: nothing to override")
  end

  -- test_key_assigned_later_binds
  do
    local env = newEnv({ keys = {} })
    env.keys = { "ENTER" }
    env.fire("UPDATE_BINDINGS")
    assert(#env.bound == 1 and env.bound[1] == "ENTER", "a key assigned later must be bound")
  end

  -- test_update_bindings_while_ineligible_stays_unbound
  do
    local env = newEnv({ on = false })
    env.keys = { "F1" }
    env.fire("UPDATE_BINDINGS")
    assert(#env.bound == 0, "a rebind must not take the key while the setting is off")
  end

  -- test_entering_world_reapplies_when_eligible
  do
    local env = newEnv()
    local before = env.binds
    env.fire("PLAYER_ENTERING_WORLD")
    assert(env.binds == before + 1, "other addons may have cleared the override by now")
    assert(#env.bound == 1, "the key must be bound once")
  end

  -- test_entering_world_while_ineligible_stays_unbound
  do
    local env = newEnv({ on = false })
    env.fire("PLAYER_ENTERING_WORLD")
    assert(env.binds == 0, "the setting is off: no override")
  end
end
