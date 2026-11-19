local RestrictionState = require("tests.helpers.restriction_state")
local Competitive = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Competitive")
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local ContentDetector = require("WhisperMessenger.Core.ContentDetector")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local PublicApi = require("WhisperMessenger.Core.PublicApi")
local RestrictionPredicates = require("tests.helpers.restriction_predicates")

local function makeHarness()
  local calls = { suspend = 0, resume = 0 }
  local Bootstrap = {
    runtime = RestrictionPredicates.Add({
      suspend = function()
        calls.suspend = calls.suspend + 1
      end,
      resume = function()
        calls.resume = calls.resume + 1
      end,
    }),
  }
  return Bootstrap, calls
end

return function()
  local savedHasMythicPlus = FlavorCompat.hasMythicPlus
  local function makeCombatHarness(hideOnCombat, visible)
    local state = { visible = visible }
    local calls = { setWindowVisible = 0 }
    local Bootstrap = {
      runtime = {
        accountState = { settings = { hideOnCombat = hideOnCombat } },
        isWindowVisible = function()
          return state.visible
        end,
      },
    }
    -- Mirrors WindowRuntime: any open clears the combat-hide mark.
    Bootstrap.runtime.setWindowVisible = function(nextVisible, showOptions)
      calls.setWindowVisible = calls.setWindowVisible + 1
      calls.lastShowOptions = showOptions
      state.visible = nextVisible
      if nextVisible then
        Bootstrap.runtime.hiddenByCombat = nil
      end
    end
    local deps = {
      getNumChatWindows = function()
        return 0
      end,
      getEditBox = function()
        return nil
      end,
    }
    return Bootstrap, deps, state, calls
  end

  -- test_combat_start_hides_visible_window_when_enabled
  do
    local Bootstrap, deps, state, calls = makeCombatHarness(true, true)

    local handled = LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_DISABLED", deps)

    assert(handled == true, "combat start should be handled")
    assert(calls.setWindowVisible == 1, "enabled combat start should hide once")
    assert(state.visible == false, "enabled combat start should hide visible window")
  end

  -- test_combat_start_does_not_hide_hidden_or_disabled_window
  do
    local hiddenBootstrap, hiddenDeps, hiddenState, hiddenCalls = makeCombatHarness(true, false)
    local hiddenHandled = LifecycleHandlers.Handle(hiddenBootstrap, "PLAYER_REGEN_DISABLED", hiddenDeps)
    assert(hiddenHandled == true, "combat start should be handled when already hidden")
    assert(hiddenCalls.setWindowVisible == 0, "already-hidden window should not be hidden again")
    assert(hiddenState.visible == false, "already-hidden window should remain hidden")

    local disabledBootstrap, disabledDeps, disabledState, disabledCalls = makeCombatHarness(false, true)
    local disabledHandled = LifecycleHandlers.Handle(disabledBootstrap, "PLAYER_REGEN_DISABLED", disabledDeps)
    assert(disabledHandled == true, "combat start should be handled when setting is disabled")
    assert(disabledCalls.setWindowVisible == 0, "disabled setting should not hide window")
    assert(disabledState.visible == true, "disabled setting should keep window visible")
  end

  -- test_manual_reopen_stays_visible_during_and_after_combat
  do
    local Bootstrap, deps, state, calls = makeCombatHarness(true, true)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_DISABLED", deps)

    Bootstrap.runtime.setWindowVisible(true)
    assert(state.visible == true, "normal visibility API should reopen during combat")

    local handled = LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_ENABLED", deps)
    assert(handled == true, "combat end should remain handled")
    assert(calls.setWindowVisible == 2, "combat end should not change window visibility")
    assert(state.visible == true, "combat end should not automatically reopen or hide window")
  end

  -- test_combat_end_reopens_window_hidden_by_combat
  do
    local Bootstrap, deps, state, calls = makeCombatHarness(true, true)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_DISABLED", deps)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_ENABLED", deps)

    assert(state.visible == true, "combat end should reopen a window combat hid")
    assert(calls.setWindowVisible == 2, "combat end should reopen once; got: " .. tostring(calls.setWindowVisible))
    assert(Bootstrap.runtime.hiddenByCombat == nil, "combat end should clear the combat-hide mark")
  end

  -- test_combat_end_reopen_does_not_take_composer_focus
  do
    local Bootstrap, deps, _state, calls = makeCombatHarness(true, true)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_DISABLED", deps)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_ENABLED", deps)

    local showOptions = calls.lastShowOptions
    assert(showOptions ~= nil and showOptions.focusComposer == false, "combat-end reopen must not focus the composer")
  end

  -- test_combat_end_keeps_window_closed_before_combat
  do
    local Bootstrap, deps, state, calls = makeCombatHarness(true, false)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_DISABLED", deps)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_ENABLED", deps)

    assert(state.visible == false, "a window closed before combat should stay closed")
    assert(calls.setWindowVisible == 0, "combat should not touch a window closed before it")
  end

  -- test_combat_end_respects_close_during_combat
  do
    local Bootstrap, deps, state = makeCombatHarness(true, true)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_DISABLED", deps)
    Bootstrap.runtime.setWindowVisible(true)
    Bootstrap.runtime.setWindowVisible(false)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_ENABLED", deps)

    assert(state.visible == false, "a window the player closed during combat should stay closed")
  end

  -- test_failed_api_open_during_combat_keeps_the_reopen
  do
    local Bootstrap, deps, state = makeCombatHarness(true, true)
    local runtime = Bootstrap.runtime
    runtime.ensureWindow = function() end
    runtime.isCompetitiveContent = function()
      return false
    end
    runtime.isMythicLockdown = function()
      return false
    end
    runtime.startConversation = function()
      return false
    end
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_DISABLED", deps)
    -- Lockdown starts after PLAYER_REGEN_DISABLED, so an addon reacting to it
    -- passes the combat guard.
    local savedInCombat = _G.InCombatLockdown
    rawset(_G, "InCombatLockdown", function()
      return false
    end)
    local opened = PublicApi.Build(runtime).OpenConversation("Jaina")
    rawset(_G, "InCombatLockdown", savedInCombat)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_ENABLED", deps)

    assert(opened == false, "the failed open should report false")
    assert(state.visible == true, "a failed API open must not cancel the combat-end reopen")
  end

  -- test_combat_end_without_setting_changes_nothing
  do
    local Bootstrap, deps, state, calls = makeCombatHarness(false, true)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_DISABLED", deps)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_ENABLED", deps)

    assert(state.visible == true, "setting off should leave the window open")
    assert(calls.setWindowVisible == 0, "setting off should never touch the window")
  end

  -- test_combat_end_does_not_reopen_during_mythic_suspend
  do
    local Bootstrap, deps, state = makeCombatHarness(true, true)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_DISABLED", deps)
    RestrictionState.Set(Bootstrap, { mythic = true })
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_ENABLED", deps)

    assert(state.visible == false, "combat end must not reopen the window while Mythic+ keeps it suspended")
    assert(Bootstrap.runtime.hiddenByCombat == nil, "combat end should clear the mark even when it does not reopen")
  end
  FlavorCompat.hasMythicPlus = true

  -- test_challenge_mode_start_suspends_once
  do
    local Bootstrap, calls = makeHarness()

    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_START")
    assert(calls.suspend == 1, "first CHALLENGE_MODE_START suspends")
    assert(RestrictionState.Flag(Bootstrap, "mythic") == true, "mythic flag set")

    -- A duplicate suspend would clobber _wasVisibleBeforeMythic (the window
    -- is already hidden by the first suspend), so it must be skipped.
    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_START")
    assert(calls.suspend == 1, "already-suspended CHALLENGE_MODE_START must not suspend again; got: " .. tostring(calls.suspend))
  end

  -- test_challenge_mode_completed_resumes_only_when_suspended
  do
    local Bootstrap, calls = makeHarness()

    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_COMPLETED")
    assert(calls.resume == 0, "COMPLETED without a prior suspend must not resume; got: " .. tostring(calls.resume))

    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_START")
    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_COMPLETED")
    assert(calls.resume == 1, "COMPLETED after a suspend resumes once")
    assert(RestrictionState.Flag(Bootstrap, "mythic") == false, "mythic flag cleared")
  end
  -- test_challenge_mode_events_are_noops_without_mythic_plus
  do
    FlavorCompat.hasMythicPlus = false
    local Bootstrap, calls = makeHarness()

    for _, event in ipairs({ "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET" }) do
      local handled = Competitive.handleChallengeModeEvent(Bootstrap, event)
      assert(handled == true, event .. " should remain claimed without Mythic+")
      assert(RestrictionState.Flag(Bootstrap, "mythic") == false, event .. " should not change mythic state without Mythic+")
    end

    assert(calls.suspend == 0, "challenge mode events must not suspend without Mythic+")
    assert(calls.resume == 0, "challenge mode events must not resume without Mythic+")
  end

  -- The instance keeps its own flag store in the three tests below, so a
  -- handler that wrote or read fields of the Bootstrap table would miss it.

  -- test_challenge_mode_events_set_and_read_the_mythic_flag_on_the_instance
  do
    FlavorCompat.hasMythicPlus = true
    local Bootstrap, calls = makeHarness()
    local instance = RestrictedActions.New()
    Bootstrap.restrictions = instance
    instance.setFlag("encounter", true)
    instance.setFlag("competitive", true)

    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_START")
    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_START")
    assert(instance.flag("mythic") == true, "CHALLENGE_MODE_START sets the mythic flag on the instance")
    assert(calls.suspend == 1, "the second start sees the flag on the instance, got " .. calls.suspend .. " suspends")

    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_COMPLETED")
    assert(calls.resume == 1, "COMPLETED resumes once, got " .. calls.resume)
    for _, name in ipairs(RestrictionState.NAMES) do
      assert(instance.flag(name) == false, "the key ending clears the " .. name .. " flag")
    end
  end

  -- test_zone_change_recomputes_flags_on_the_instance
  do
    local savedGetInstanceInfo = rawget(_G, "GetInstanceInfo")
    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)
    local Bootstrap, calls = makeHarness()
    local instance = RestrictedActions.New()
    Bootstrap.restrictions = instance
    instance.setFlag("competitive", true)
    instance.setFlag("mythic", true)

    Competitive.handleZoneChangedNewArea(Bootstrap, {
      getContentDetector = function()
        return ContentDetector
      end,
      getPresenceCache = function()
        return nil
      end,
    })
    rawset(_G, "GetInstanceInfo", savedGetInstanceInfo)

    assert(instance.flag("competitive") == false, "leaving PvP clears the competitive flag on the instance")
    assert(instance.flag("mythic") == false, "leaving the dungeon clears the mythic flag on the instance")
    assert(calls.resume == 1, "leaving the dungeon resumes once, got " .. calls.resume)
  end

  -- test_combat_end_reads_the_mythic_flag_from_the_instance
  do
    local Bootstrap, deps, state = makeCombatHarness(true, true)
    local instance = RestrictedActions.New()
    Bootstrap.restrictions = instance
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_DISABLED", deps)
    instance.setFlag("mythic", true)
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_REGEN_ENABLED", deps)

    assert(state.visible == false, "combat end must not reopen the window while the instance says Mythic+")
  end

  FlavorCompat.hasMythicPlus = savedHasMythicPlus
end
