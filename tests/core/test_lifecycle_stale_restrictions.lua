-- A restriction's Inactive event can be lost across a loading screen (leaving
-- Mythic+ or a raid). Entering the world drops a cached lock the game itself
-- no longer reports, so sends aren't held back in the open world.
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local ContentDetector = require("WhisperMessenger.Core.ContentDetector")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

local ENCOUNTER, CHALLENGE_MODE = 1, 2
local ACTIVATING, ACTIVE = 1, 2

local deps = {
  getContentDetector = function()
    return ContentDetector
  end,
  getPresenceCache = function()
    return nil
  end,
}

local apiActive = {}
local deferred = {}

local function newBootstrap()
  local restrictedActions = RestrictedActions.New()
  return {
    runtime = {
      restrictedActions = restrictedActions,
      suspend = function() end,
      resume = function() end,
    },
  }
end

local function event(Bootstrap, restrictionType, state)
  LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", deps, restrictionType, state)
end

local function enterWorld(Bootstrap)
  LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", deps)
end

local function flushTimers()
  local queued = deferred
  deferred = {}
  for _, callback in ipairs(queued) do
    callback()
  end
end

return function()
  local saved = {
    restricted = _G.C_RestrictedActions,
    timer = _G.C_Timer,
    instanceInfo = rawget(_G, "GetInstanceInfo"),
  }
  _G.C_Timer = {
    After = function(_delay, callback)
      deferred[#deferred + 1] = callback
    end,
  }
  _G.C_RestrictedActions = {
    IsAddOnRestrictionActive = function(restrictionType)
      return apiActive[restrictionType] == true
    end,
  }
  rawset(_G, "GetInstanceInfo", function()
    return "Dornogal", "none", 0
  end)

  -- test_lost_inactive_after_mythic_plus_unlocks_sends
  do
    apiActive = {}
    local Bootstrap = newBootstrap()
    event(Bootstrap, CHALLENGE_MODE, ACTIVE)
    event(Bootstrap, ENCOUNTER, ACTIVE)
    enterWorld(Bootstrap)
    local restrictedActions = Bootstrap.runtime.restrictedActions
    assert(restrictedActions.isMythic() == false, "a Mythic+ lock the game no longer reports must clear")
    assert(restrictedActions.isCompetitive() == false, "a boss lock the game no longer reports must clear")
  end

  -- test_lock_the_game_still_reports_survives
  do
    apiActive = { [ENCOUNTER] = true }
    local Bootstrap = newBootstrap()
    event(Bootstrap, ENCOUNTER, ACTIVE)
    enterWorld(Bootstrap)
    assert(Bootstrap.runtime.restrictedActions.isCompetitive() == true, "a lock the game still reports must stay")
  end

  -- test_lock_survives_without_the_api
  do
    apiActive = {}
    local Bootstrap = newBootstrap()
    event(Bootstrap, ENCOUNTER, ACTIVE)
    local api = _G.C_RestrictedActions
    _G.C_RestrictedActions = nil
    enterWorld(Bootstrap)
    _G.C_RestrictedActions = api
    assert(Bootstrap.runtime.restrictedActions.isCompetitive() == true, "without the API a cached lock must stay")
  end

  -- test_stale_activating_clears_after_grace
  do
    apiActive = {}
    deferred = {}
    local Bootstrap = newBootstrap()
    event(Bootstrap, CHALLENGE_MODE, ACTIVATING)
    enterWorld(Bootstrap)
    assert(Bootstrap.runtime.restrictedActions.isMythic() == true, "Activating must survive entering the world")
    flushTimers()
    assert(Bootstrap.runtime.restrictedActions.isMythic() == false, "Activating with no follow-up event must clear after the grace")
  end

  -- test_activating_grace_keeps_a_fresh_event
  do
    apiActive = {}
    deferred = {}
    local Bootstrap = newBootstrap()
    event(Bootstrap, CHALLENGE_MODE, ACTIVATING)
    enterWorld(Bootstrap)
    event(Bootstrap, CHALLENGE_MODE, ACTIVATING)
    flushTimers()
    assert(Bootstrap.runtime.restrictedActions.isMythic() == true, "a fresh Activating event must not be cleared by the grace")
  end

  _G.C_RestrictedActions = saved.restricted
  _G.C_Timer = saved.timer
  rawset(_G, "GetInstanceInfo", saved.instanceInfo)
end
