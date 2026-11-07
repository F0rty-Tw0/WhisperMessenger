local FakeUI = require("tests.helpers.fake_ui")
local Env = require("tests.helpers.composer_send_focus_env")

local newEnv = Env.NewEnv

return function()
  local savedUIParent = _G.UIParent

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

  _G.UIParent = savedUIParent
end
