local RestrictionState = require("tests.helpers.restriction_state")
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local RestrictionPredicates = require("tests.helpers.restriction_predicates")

-- A fake Bootstrap wired as Bootstrap.Initialize wires the real one: the
-- runtime keeps the Bootstrap table's restriction instance.
local function newBootstrap(fields, flags)
  local Bootstrap = RestrictionState.Set(fields, flags)
  Bootstrap.runtime.restrictedActions = Bootstrap.restrictions
  RestrictionPredicates.Add(Bootstrap.runtime)
  return Bootstrap
end

return function()
  -- test_addon_restriction_challenge_mode_active_triggers_suspend

  do
    local suspendCalls, resumeCalls = 0, 0
    local Bootstrap = newBootstrap({
      runtime = {
        suspend = function()
          suspendCalls = suspendCalls + 1
        end,
        resume = function()
          resumeCalls = resumeCalls + 1
        end,
      },
    })

    local handled = LifecycleHandlers.Handle(
      Bootstrap,
      "ADDON_RESTRICTION_STATE_CHANGED",
      {},
      RestrictedActions.TYPES.ChallengeMode,
      RestrictedActions.STATES.Active
    )

    assert(handled == true, "Handle should claim the ADDON_RESTRICTION_STATE_CHANGED event")
    assert(RestrictionState.Flag(Bootstrap, "mythic") == true, "ChallengeMode active should set the mythic flag")
    assert(suspendCalls == 1, "should call runtime.suspend exactly once, got " .. suspendCalls)
    assert(Bootstrap.runtime.restrictedActions.isMythic() == true, "restrictedActions instance must reflect the cached payload state")
  end

  -- test_addon_restriction_challenge_mode_inactive_triggers_resume

  do
    local suspendCalls, resumeCalls = 0, 0
    local Bootstrap = newBootstrap({
      runtime = {
        suspend = function()
          suspendCalls = suspendCalls + 1
        end,
        resume = function()
          resumeCalls = resumeCalls + 1
        end,
      },
    }, { mythic = true })

    local handled = LifecycleHandlers.Handle(
      Bootstrap,
      "ADDON_RESTRICTION_STATE_CHANGED",
      {},
      RestrictedActions.TYPES.ChallengeMode,
      RestrictedActions.STATES.Inactive
    )

    assert(handled == true, "Handle should claim the event")
    assert(RestrictionState.Flag(Bootstrap, "mythic") == false, "ChallengeMode inactive should clear the mythic flag")
    assert(resumeCalls == 1, "should call runtime.resume exactly once, got " .. resumeCalls)
  end

  -- test_addon_restriction_encounter_active_toggles_filters

  do
    local syncCalls = 0
    local Bootstrap = newBootstrap({
      runtime = {},
      syncChatFilters = function()
        syncCalls = syncCalls + 1
      end,
    })

    LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", {}, RestrictedActions.TYPES.Encounter, RestrictedActions.STATES.Active)

    assert(RestrictionState.Flag(Bootstrap, "encounter") == true, "Encounter active should set the encounter flag")
    assert(syncCalls == 1, "should sync chat filters once on encounter state change")
  end

  -- test_addon_restriction_reads_state_from_payload_not_api

  -- API returns false during event dispatch — must trust the payload.
  do
    local savedApi = _G.C_RestrictedActions
    _G.C_RestrictedActions = {
      IsAddOnRestrictionActive = function()
        return false -- lies during dispatch
      end,
    }

    local Bootstrap = newBootstrap({
      runtime = {
        suspend = function() end,
        resume = function() end,
      },
    })

    LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", {}, RestrictedActions.TYPES.ChallengeMode, RestrictedActions.STATES.Active)

    assert(Bootstrap.runtime.restrictedActions.isMythic() == true, "payload must win over lying IsAddOnRestrictionActive during dispatch")

    _G.C_RestrictedActions = savedApi
  end

  -- test_restriction_events_set_and_read_flags_on_the_instance
  -- The instance keeps its own flag store here, so a handler that wrote or
  -- read fields of the Bootstrap table would miss it.
  do
    local TYPES, STATES = RestrictedActions.TYPES, RestrictedActions.STATES
    local suspendCalls, resumeCalls = 0, 0
    local instance = RestrictedActions.New()
    local Bootstrap = {
      restrictions = instance,
      runtime = RestrictionPredicates.Add({
        restrictedActions = instance,
        suspend = function()
          suspendCalls = suspendCalls + 1
        end,
        resume = function()
          resumeCalls = resumeCalls + 1
        end,
      }),
    }
    local function report(restrictionType, state)
      LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", {}, restrictionType, state)
    end

    report(TYPES.ChallengeMode, STATES.Active)
    assert(instance.flag("mythic") == true, "ChallengeMode active sets the mythic flag on the instance")
    report(TYPES.ChallengeMode, STATES.Active)
    assert(suspendCalls == 1, "the second Active sees the flag already set and does not suspend again, got " .. suspendCalls)

    report(TYPES.Encounter, STATES.Active)
    assert(instance.flag("encounter") == true, "Encounter active sets the encounter flag on the instance")
    report(TYPES.PvPMatch, STATES.Active)
    assert(instance.flag("competitive") == true, "PvPMatch active sets the competitive flag on the instance")

    report(TYPES.ChallengeMode, STATES.Inactive)
    assert(resumeCalls == 1, "ChallengeMode inactive resumes once, got " .. resumeCalls)
    for _, name in ipairs(RestrictionState.NAMES) do
      assert(instance.flag(name) == false, "the key ending clears the " .. name .. " flag")
    end
  end

  -- test_restriction_event_reaches_the_instance_cache_without_a_runtime_copy
  do
    local instance = RestrictedActions.New()
    local Bootstrap = { restrictions = instance, runtime = RestrictionPredicates.Add({}) }
    LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", {}, RestrictedActions.TYPES.PvPMatch, RestrictedActions.STATES.Active)
    assert(instance.cachedState(RestrictedActions.TYPES.PvPMatch) == RestrictedActions.STATES.Active, "the event payload is cached on the instance")
  end
end
