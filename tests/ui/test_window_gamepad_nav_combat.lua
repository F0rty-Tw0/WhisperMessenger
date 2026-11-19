local FakeUI = require("tests.helpers.fake_ui")
local FakeGamepad = require("tests.helpers.fake_gamepad")
local GamepadNav = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.GamepadNav")

local function setup()
  local env = FakeGamepad.New()
  local frame = FakeUI.NewFactory().CreateFrame("Frame", "WhisperMessengerWindow", nil)
  return env, frame, GamepadNav.New(frame, env.deps())
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
  -- test_show_in_combat_registers_on_regen
  do
    local env, _, nav = setup()
    env.combat = true
    nav.onShow()
    assert(#env.calls == 0, "no call in combat")
    endCombat(env)
    assert(names(env) == "FrameShown" and nav.isRegistered(), "registered after combat")
  end

  -- test_show_then_hide_in_combat_makes_no_call
  do
    local env, _, nav = setup()
    env.combat = true
    nav.onShow()
    nav.onHide()
    endCombat(env)
    assert(#env.calls == 0, "pending register cleared by the hide")
  end

  -- test_hide_in_combat_while_registered_unregisters_on_regen
  do
    local env, _, nav = setup()
    nav.onShow()
    env.combat = true
    nav.onHide()
    assert(env.count("FrameHidden") == 0, "blocked in combat")
    endCombat(env)
    assert(names(env) == "FrameShown,FrameHidden" and not nav.isRegistered(), "GH → H")
  end

  -- test_reshown_in_combat_from_gh_hides_then_shows_on_regen
  do
    local env, _, nav = setup()
    nav.onShow()
    env.combat = true
    nav.onHide()
    nav.onShow()
    endCombat(env)
    assert(names(env) == "FrameShown,FrameHidden,FrameShown" and nav.isRegistered(), "GH → GC → G")
  end

  -- test_regen_while_still_restricted_retries_next_frame
  do
    local env, _, nav = setup()
    env.combat = true
    nav.onShow()
    env.regen()
    env.flush()
    assert(#env.calls == 0, "still restricted: no call")
    env.combat = false
    env.flush()
    assert(names(env) == "FrameShown", "retried once the test clears")
  end

  -- test_refresh_in_combat_runs_once_after_regen
  do
    local env, _, nav = setup()
    nav.onShow()
    env.combat = true
    nav.refresh()
    nav.refresh()
    env.flush()
    assert(env.count("RefreshButtonGroups") == 0, "none in combat")
    endCombat(env)
    assert(env.count("RefreshButtonGroups") == 1, "one after regen")
  end

  -- test_ignore_in_combat_is_queued_and_done_once
  do
    local env, _, nav = setup()
    local widget = {}
    env.combat = true
    nav.ignore(widget)
    nav.ignore(widget)
    assert(env.count("MarkFrameIgnored") == 0, "queued")
    endCombat(env)
    assert(env.count("MarkFrameIgnored") == 1, "done once")
  end

  -- test_regen_settles_ignores_then_register_then_refresh
  do
    local env, _, nav = setup()
    env.combat = true
    nav.onShow()
    nav.ignore({})
    endCombat(env)
    nav.refresh()
    env.flush()
    assert(names(env) == "MarkFrameIgnored,FrameShown,RefreshButtonGroups", "spec §5 settling order")
  end

  -- test_panel_info_in_combat_does_not_set_scroll_frame
  do
    local env, frame, nav = setup()
    nav.setScrollFrame({})
    env.combat = true
    frame.smartNavPanelInfoAddedCallback({})
    assert(env.count("SetScrollFrameForFrame") == 0, "wrapped call blocked in combat")
  end

  -- test_regen_with_nothing_pending_makes_no_call
  do
    local env, _, nav = setup()
    nav.onShow()
    endCombat(env)
    assert(names(env) == "FrameShown", "G + regen: nothing")
  end

  -- test_default_combat_check_uses_the_game_globals
  do
    local env = FakeGamepad.New()
    local frame = FakeUI.NewFactory().CreateFrame("Frame", "WhisperMessengerWindow", nil)
    local savedEnum = rawget(_G, "Enum")
    env.install()
    local ok, err = pcall(function()
      local nav = GamepadNav.New(frame, { isForever = true, after = env.after, createFrame = env.createFrame })
      env.combat = true
      nav.onShow()
      assert(#env.calls == 0, "InCombatLockdown blocks the call")
      env.combat = false
      local restricted = true
      rawset(_G, "Enum", { AddOnRestrictionType = { Combat = 7 } })
      rawset(_G, "C_RestrictedActions", {
        IsAddOnRestrictionActive = function(restrictionType)
          return restrictionType == 7 and restricted
        end,
      })
      nav.onHide()
      nav.onShow()
      assert(#env.calls == 0, "the combat restriction wins over InCombatLockdown")
      restricted = false
      nav.onShow()
      assert(names(env) == "FrameShown", "no restriction: registers")
    end)
    env.uninstall()
    rawset(_G, "Enum", savedEnum)
    assert(ok, err)
  end
end
