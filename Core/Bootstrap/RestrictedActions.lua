local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Thin abstraction over 12.0's C_RestrictedActions API.
--
-- The authoritative "is the player in restricted content?" source is
-- ADDON_RESTRICTION_STATE_CHANGED: it fires with (type, state) whenever a
-- restriction transitions. The state must be read from the event payload,
-- NOT re-queried via C_RestrictedActions.IsAddOnRestrictionActive, because
-- that API returns false during dispatch of its own event.
--
-- Pre-12.0 clients don't have C_RestrictedActions. We fall back to the
-- existing flag-based approach (Bootstrap._inCompetitiveContent, etc.).
local RestrictedActions = {}

-- Mirrors Enum.AddOnRestrictionType
RestrictedActions.TYPES = {
  Combat = 0,
  Encounter = 1,
  ChallengeMode = 2,
  PvPMatch = 3,
  Map = 4,
}

-- Mirrors Enum.AddOnRestrictionState
RestrictedActions.STATES = {
  Inactive = 0,
  Activating = 1,
  Active = 2,
}

function RestrictedActions.IsAvailable()
  local api = _G.C_RestrictedActions
  return api ~= nil and type(api.IsAddOnRestrictionActive) == "function"
end

function RestrictedActions.New()
  local cached = {}
  local self = {}

  function self.updateFromEvent(restrictionType, newState)
    if type(restrictionType) ~= "number" or type(newState) ~= "number" then
      return
    end
    cached[restrictionType] = newState
  end

  function self.isActive(restrictionType)
    local s = cached[restrictionType]
    if s ~= nil then
      return s == RestrictedActions.STATES.Active or s == RestrictedActions.STATES.Activating
    end
    local api = _G.C_RestrictedActions
    if api and type(api.IsAddOnRestrictionActive) == "function" then
      local ok, result = pcall(api.IsAddOnRestrictionActive, restrictionType)
      if ok then
        return result == true
      end
    end
    return false
  end

  function self.isCompetitive()
    return self.isActive(RestrictedActions.TYPES.Encounter)
      or self.isActive(RestrictedActions.TYPES.ChallengeMode)
      or self.isActive(RestrictedActions.TYPES.PvPMatch)
  end

  function self.isMythic()
    return self.isActive(RestrictedActions.TYPES.ChallengeMode)
  end

  function self.isCombat()
    return self.isActive(RestrictedActions.TYPES.Combat)
  end

  return self
end

ns.BootstrapRestrictedActions = RestrictedActions
return RestrictedActions
