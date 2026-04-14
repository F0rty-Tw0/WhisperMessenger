local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

return function()
  -- -----------------------------------------------------------------------
  -- test_type_and_state_constants_match_blizzard_enum
  -- -----------------------------------------------------------------------
  do
    assert(RestrictedActions.TYPES.Combat == 0, "Combat must be 0 per Enum.AddOnRestrictionType")
    assert(RestrictedActions.TYPES.Encounter == 1, "Encounter must be 1")
    assert(RestrictedActions.TYPES.ChallengeMode == 2, "ChallengeMode must be 2")
    assert(RestrictedActions.TYPES.PvPMatch == 3, "PvPMatch must be 3")
    assert(RestrictedActions.TYPES.Map == 4, "Map must be 4")

    assert(RestrictedActions.STATES.Inactive == 0, "Inactive must be 0")
    assert(RestrictedActions.STATES.Activating == 1, "Activating must be 1")
    assert(RestrictedActions.STATES.Active == 2, "Active must be 2")
  end

  -- -----------------------------------------------------------------------
  -- test_update_from_event_persists_state_without_api_call
  -- -----------------------------------------------------------------------
  -- ADDON_RESTRICTION_STATE_CHANGED returns false from IsAddOnRestrictionActive
  -- during event dispatch. Must read from payload, never re-query.
  do
    local queryCount = 0
    local savedApi = _G.C_RestrictedActions
    _G.C_RestrictedActions = {
      IsAddOnRestrictionActive = function(_type)
        queryCount = queryCount + 1
        return false -- simulate the broken-during-dispatch behaviour
      end,
    }

    local instance = RestrictedActions.New()
    instance.updateFromEvent(RestrictedActions.TYPES.ChallengeMode, RestrictedActions.STATES.Active)

    assert(
      instance.isActive(RestrictedActions.TYPES.ChallengeMode) == true,
      "ChallengeMode should read as active from cached event payload"
    )
    assert(queryCount == 0, "must NOT call IsAddOnRestrictionActive when cached state exists")

    _G.C_RestrictedActions = savedApi
  end

  -- -----------------------------------------------------------------------
  -- test_activating_state_is_treated_as_active
  -- -----------------------------------------------------------------------
  do
    local instance = RestrictedActions.New()
    instance.updateFromEvent(RestrictedActions.TYPES.Encounter, RestrictedActions.STATES.Activating)
    assert(
      instance.isActive(RestrictedActions.TYPES.Encounter) == true,
      "Activating state must block addon actions just like Active"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_inactive_state_resets_cached_activation
  -- -----------------------------------------------------------------------
  do
    local instance = RestrictedActions.New()
    instance.updateFromEvent(RestrictedActions.TYPES.Encounter, RestrictedActions.STATES.Active)
    assert(instance.isActive(RestrictedActions.TYPES.Encounter) == true)
    instance.updateFromEvent(RestrictedActions.TYPES.Encounter, RestrictedActions.STATES.Inactive)
    assert(
      instance.isActive(RestrictedActions.TYPES.Encounter) == false,
      "Inactive state must clear previous activation"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_is_competitive_covers_encounter_challenge_pvp
  -- -----------------------------------------------------------------------
  do
    local instance = RestrictedActions.New()
    assert(instance.isCompetitive() == false, "fresh instance should not be competitive")

    instance.updateFromEvent(RestrictedActions.TYPES.Encounter, RestrictedActions.STATES.Active)
    assert(instance.isCompetitive() == true, "Encounter should count as competitive")
    instance.updateFromEvent(RestrictedActions.TYPES.Encounter, RestrictedActions.STATES.Inactive)

    instance.updateFromEvent(RestrictedActions.TYPES.ChallengeMode, RestrictedActions.STATES.Active)
    assert(instance.isCompetitive() == true, "ChallengeMode should count as competitive")
    assert(instance.isMythic() == true, "ChallengeMode specifically indicates mythic")
    instance.updateFromEvent(RestrictedActions.TYPES.ChallengeMode, RestrictedActions.STATES.Inactive)

    instance.updateFromEvent(RestrictedActions.TYPES.PvPMatch, RestrictedActions.STATES.Active)
    assert(instance.isCompetitive() == true, "PvPMatch should count as competitive")
    assert(instance.isMythic() == false, "PvPMatch should NOT flag as mythic")
  end

  -- -----------------------------------------------------------------------
  -- test_falls_back_to_api_when_no_cached_state
  -- -----------------------------------------------------------------------
  do
    local savedApi = _G.C_RestrictedActions
    _G.C_RestrictedActions = {
      IsAddOnRestrictionActive = function(t)
        return t == RestrictedActions.TYPES.Combat
      end,
    }

    local instance = RestrictedActions.New()
    assert(instance.isActive(RestrictedActions.TYPES.Combat) == true, "fallback query should return true for Combat")
    assert(
      instance.isActive(RestrictedActions.TYPES.Encounter) == false,
      "fallback query should return false for Encounter"
    )

    _G.C_RestrictedActions = savedApi
  end

  -- -----------------------------------------------------------------------
  -- test_is_available_guards_pre_midnight_clients
  -- -----------------------------------------------------------------------
  do
    local savedApi = _G.C_RestrictedActions
    _G.C_RestrictedActions = nil
    assert(RestrictedActions.IsAvailable() == false, "should report unavailable when C_RestrictedActions is missing")

    _G.C_RestrictedActions = {
      IsAddOnRestrictionActive = function()
        return false
      end,
    }
    assert(RestrictedActions.IsAvailable() == true, "should report available when API exists")

    _G.C_RestrictedActions = savedApi
  end
end
