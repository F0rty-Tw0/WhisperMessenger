local Competitive = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Competitive")
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")

local function makeHarness()
  local calls = { suspend = 0, resume = 0 }
  local Bootstrap = {
    _inMythicContent = false,
    runtime = {
      suspend = function()
        calls.suspend = calls.suspend + 1
      end,
      resume = function()
        calls.resume = calls.resume + 1
      end,
    },
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
        setWindowVisible = function(nextVisible)
          calls.setWindowVisible = calls.setWindowVisible + 1
          state.visible = nextVisible
        end,
      },
    }
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
  FlavorCompat.hasMythicPlus = true

  -- test_challenge_mode_start_suspends_once
  do
    local Bootstrap, calls = makeHarness()

    Competitive.handleChallengeModeEvent(Bootstrap, "CHALLENGE_MODE_START")
    assert(calls.suspend == 1, "first CHALLENGE_MODE_START suspends")
    assert(Bootstrap._inMythicContent == true, "mythic flag set")

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
    assert(Bootstrap._inMythicContent == false, "mythic flag cleared")
  end
  -- test_challenge_mode_events_are_noops_without_mythic_plus
  do
    FlavorCompat.hasMythicPlus = false
    local Bootstrap, calls = makeHarness()

    for _, event in ipairs({ "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET" }) do
      local handled = Competitive.handleChallengeModeEvent(Bootstrap, event)
      assert(handled == true, event .. " should remain claimed without Mythic+")
      assert(Bootstrap._inMythicContent == false, event .. " should not change mythic state without Mythic+")
    end

    assert(calls.suspend == 0, "challenge mode events must not suspend without Mythic+")
    assert(calls.resume == 0, "challenge mode events must not resume without Mythic+")
  end

  FlavorCompat.hasMythicPlus = savedHasMythicPlus
end
