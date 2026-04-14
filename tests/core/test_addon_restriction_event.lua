local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

return function()
  local function makeDeps()
    local calls = {}
    return {
      trace = function(...)
        table.insert(calls, { ... })
      end,
      getContentDetector = function()
        return {
          IsCompetitiveContent = function()
            return false
          end,
          IsMythicRestricted = function()
            return false
          end,
        }
      end,
      getPresenceCache = function()
        return nil
      end,
      loadModule = function()
        return nil
      end,
      _calls = calls,
    }
  end

  -- -----------------------------------------------------------------------
  -- test_addon_restriction_challenge_mode_active_triggers_suspend
  -- -----------------------------------------------------------------------
  do
    local suspendCalls, resumeCalls = 0, 0
    local Bootstrap = {
      _inMythicContent = false,
      _inEncounter = false,
      _inCompetitiveContent = false,
      runtime = {
        restrictedActions = RestrictedActions.New(),
        suspend = function()
          suspendCalls = suspendCalls + 1
        end,
        resume = function()
          resumeCalls = resumeCalls + 1
        end,
      },
    }

    local handled = LifecycleHandlers.Handle(
      Bootstrap,
      "ADDON_RESTRICTION_STATE_CHANGED",
      makeDeps(),
      RestrictedActions.TYPES.ChallengeMode,
      RestrictedActions.STATES.Active
    )

    assert(handled == true, "Handle should claim the ADDON_RESTRICTION_STATE_CHANGED event")
    assert(Bootstrap._inMythicContent == true, "ChallengeMode active should set _inMythicContent")
    assert(suspendCalls == 1, "should call runtime.suspend exactly once, got " .. suspendCalls)
    assert(
      Bootstrap.runtime.restrictedActions.isMythic() == true,
      "restrictedActions instance must reflect the cached payload state"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_addon_restriction_challenge_mode_inactive_triggers_resume
  -- -----------------------------------------------------------------------
  do
    local suspendCalls, resumeCalls = 0, 0
    local Bootstrap = {
      _inMythicContent = true,
      _inEncounter = false,
      _inCompetitiveContent = false,
      runtime = {
        restrictedActions = RestrictedActions.New(),
        suspend = function()
          suspendCalls = suspendCalls + 1
        end,
        resume = function()
          resumeCalls = resumeCalls + 1
        end,
      },
    }

    local handled = LifecycleHandlers.Handle(
      Bootstrap,
      "ADDON_RESTRICTION_STATE_CHANGED",
      makeDeps(),
      RestrictedActions.TYPES.ChallengeMode,
      RestrictedActions.STATES.Inactive
    )

    assert(handled == true, "Handle should claim the event")
    assert(Bootstrap._inMythicContent == false, "ChallengeMode inactive should clear _inMythicContent")
    assert(resumeCalls == 1, "should call runtime.resume exactly once, got " .. resumeCalls)
  end

  -- -----------------------------------------------------------------------
  -- test_addon_restriction_encounter_active_toggles_filters
  -- -----------------------------------------------------------------------
  do
    local syncCalls = 0
    local Bootstrap = {
      _inEncounter = false,
      _inMythicContent = false,
      _inCompetitiveContent = false,
      runtime = { restrictedActions = RestrictedActions.New() },
      syncChatFilters = function()
        syncCalls = syncCalls + 1
      end,
    }

    LifecycleHandlers.Handle(
      Bootstrap,
      "ADDON_RESTRICTION_STATE_CHANGED",
      makeDeps(),
      RestrictedActions.TYPES.Encounter,
      RestrictedActions.STATES.Active
    )

    assert(Bootstrap._inEncounter == true, "Encounter active should set _inEncounter=true")
    assert(syncCalls == 1, "should sync chat filters once on encounter state change")
  end

  -- -----------------------------------------------------------------------
  -- test_addon_restriction_reads_state_from_payload_not_api
  -- -----------------------------------------------------------------------
  -- API returns false during event dispatch — must trust the payload.
  do
    local savedApi = _G.C_RestrictedActions
    _G.C_RestrictedActions = {
      IsAddOnRestrictionActive = function()
        return false -- lies during dispatch
      end,
    }

    local Bootstrap = {
      _inMythicContent = false,
      _inEncounter = false,
      _inCompetitiveContent = false,
      runtime = {
        restrictedActions = RestrictedActions.New(),
        suspend = function() end,
        resume = function() end,
      },
    }

    LifecycleHandlers.Handle(
      Bootstrap,
      "ADDON_RESTRICTION_STATE_CHANGED",
      makeDeps(),
      RestrictedActions.TYPES.ChallengeMode,
      RestrictedActions.STATES.Active
    )

    assert(
      Bootstrap.runtime.restrictedActions.isMythic() == true,
      "payload must win over lying IsAddOnRestrictionActive during dispatch"
    )

    _G.C_RestrictedActions = savedApi
  end
end
