-- The detection flags and the 12.0 restriction state can disagree: entering
-- the world or changing zone rewrites the flags from the instance type, and
-- completing a key clears them, while the game goes on reporting a
-- restriction. Sends, the paused notice, the icon and the chat filters must
-- then all follow the game, through the real Bootstrap and lifecycle handlers.
local RestrictionState = require("tests.helpers.restriction_state")
local RestrictionWorld = require("tests.helpers.restriction_world")
local Bootstrap = require("WhisperMessenger.Bootstrap")
local Common = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Common")
local ContentDetector = require("WhisperMessenger.Core.ContentDetector")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local Localization = require("WhisperMessenger.Locale.Localization")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")
local StaleRestrictions = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.StaleRestrictions")

local TYPES, STATES = RestrictedActions.TYPES, RestrictedActions.STATES

local DEPS = {
  getContentDetector = function()
    return ContentDetector
  end,
  getPresenceCache = function()
    return nil
  end,
}

local function standIn(instanceType, difficultyID)
  rawset(_G, "GetInstanceInfo", function()
    return "Somewhere", instanceType, difficultyID
  end)
end

-- A fresh runtime with whisper and channel hiding on; world.iconTold is the
-- last thing the icon heard.
local function boot(world)
  RestrictionState.Set(Bootstrap, {})
  rawset(_G, "C_RestrictedActions", world.restrictedApi)
  world.filters = {}
  world.apiSaysYes = {}
  local runtime = Bootstrap.Initialize(world.factory, {
    accountState = {
      schemaVersion = 1,
      conversations = {},
      contacts = {},
      pendingHydration = {},
      settings = { hideFromDefaultChat = true, hideChannelsFromDefaultChat = true, enabledChannels = { trade = true } },
    },
    characterState = { window = { x = 0, y = 0, width = 900, height = 560 }, icon = {} },
    localProfileId = "me",
  })
  Bootstrap.runtime = runtime
  local tellIcon = Bootstrap.onCompetitiveStateChanged
  Bootstrap.onCompetitiveStateChanged = function(isActive)
    world.iconTold = isActive
    return tellIcon(isActive)
  end
  return runtime
end

local function assertPaused(world, runtime, notice, what)
  assert(runtime.isCompetitiveContent() == true, what .. ": sends are held")
  assert(world.filters.CHAT_MSG_WHISPER == nil, what .. ": whispers stay in the default chat")
  assert(world.filters.CHAT_MSG_CHANNEL == nil, what .. ": channel lines stay in the default chat")
  assert(runtime.messagingNotice == notice, what .. ": the paused notice is shown")
  assert(world.iconTold == true, what .. ": the icon is told")
end

local function assertOpen(world, runtime, what)
  assert(runtime.isCompetitiveContent() == false, what .. ": sends go out")
  assert(world.filters.CHAT_MSG_WHISPER ~= nil, what .. ": whispers are hidden from the default chat again")
  assert(world.filters.CHAT_MSG_CHANNEL ~= nil, what .. ": channel lines are hidden again")
  assert(runtime.messagingNotice == nil, what .. ": the paused notice is gone")
  assert(world.iconTold == false, what .. ": the icon is told")
end

return function()
  Localization.Configure({ language = "enUS" })
  local notice = Localization.Text(Common.COMPETITIVE_NOTICE)
  local saved = { info = rawget(_G, "GetInstanceInfo"), timer = rawget(_G, "C_Timer"), mythicPlus = FlavorCompat.hasMythicPlus }
  FlavorCompat.hasMythicPlus = true
  -- Only the stale-Activating grace timer is kept, to be run by hand.
  local graceTimers = {}
  rawset(_G, "C_Timer", {
    After = function(delay, callback)
      if delay == StaleRestrictions.ACTIVATING_GRACE_SECONDS then
        graceTimers[#graceTimers + 1] = callback
      end
    end,
  })

  local world = RestrictionWorld.Install()
  local ok, err = pcall(function()
    RestrictionWorld.Start(world)

    -- test_reload_during_a_boss_fight_follows_the_game_not_the_flags
    -- No event after a reload: only the game API knows about the fight.
    do
      local runtime = boot(world)
      standIn("raid", 16)
      world.apiSaysYes[TYPES.Encounter] = true
      LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", DEPS)
      for _, name in ipairs(RestrictionState.NAMES) do
        assert(RestrictionState.Flag(Bootstrap, name) == false, "entering a raid leaves the " .. name .. " flag clear")
      end
      assertPaused(world, runtime, notice, "boss fight after a reload")

      world.apiSaysYes[TYPES.Encounter] = false
      LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", DEPS)
      assertOpen(world, runtime, "fight over")
    end

    -- test_zone_change_inside_a_pvp_match_follows_the_cache_not_the_flags
    -- The match's restriction event is cached; the zone then reads as open
    -- world and clears the competitive flag while the match is still on.
    do
      local runtime = boot(world)
      standIn("pvp", 1)
      LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", DEPS, TYPES.PvPMatch, STATES.Active)
      standIn("none", 0)
      LifecycleHandlers.Handle(Bootstrap, "ZONE_CHANGED_NEW_AREA", DEPS)
      assert(RestrictionState.Flag(Bootstrap, "competitive") == false, "the zone change cleared the competitive flag")
      assertPaused(world, runtime, notice, "zone change in a PvP match")

      LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", DEPS, TYPES.PvPMatch, STATES.Inactive)
      assertOpen(world, runtime, "match over")
    end

    -- test_key_completed_before_its_restriction_lifts_gets_the_filters_back
    -- Completing the key clears the mythic flag and resumes while the game
    -- still reports the restriction; the Inactive that follows finds no flag.
    do
      local runtime = boot(world)
      standIn("party", 8)
      LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", DEPS, TYPES.ChallengeMode, STATES.Active)
      LifecycleHandlers.Handle(Bootstrap, "CHALLENGE_MODE_COMPLETED", DEPS)
      assert(RestrictionState.Flag(Bootstrap, "mythic") == false, "completing the key cleared the mythic flag")
      assertPaused(world, runtime, notice, "key completed, restriction still on")

      LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", DEPS, TYPES.ChallengeMode, STATES.Inactive)
      assertOpen(world, runtime, "key restriction lifted")
    end

    -- test_key_only_the_game_reports_gets_the_filters_back
    -- No flag and no suspend: entering the world reads the key from the API.
    do
      local runtime = boot(world)
      standIn("party", 23)
      world.apiSaysYes[TYPES.ChallengeMode] = true
      LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", DEPS)
      assert(RestrictionState.Flag(Bootstrap, "mythic") == false, "the mythic flag stays clear")
      assertPaused(world, runtime, notice, "key only the game reports")

      world.apiSaysYes[TYPES.ChallengeMode] = false
      LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", DEPS, TYPES.ChallengeMode, STATES.Inactive)
      assertOpen(world, runtime, "key the game reported is over")
    end

    -- test_replayed_inactive_for_a_stale_activating_key_gets_the_filters_back
    -- The key's Inactive was lost across the loading screen out of the
    -- dungeon; the grace timer replays it after the world entry resumed.
    do
      local runtime = boot(world)
      standIn("party", 8)
      LifecycleHandlers.Handle(Bootstrap, "ADDON_RESTRICTION_STATE_CHANGED", DEPS, TYPES.ChallengeMode, STATES.Activating)
      standIn("none", 0)
      graceTimers = {}
      LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", DEPS)
      assert(RestrictionState.Flag(Bootstrap, "mythic") == false, "leaving the dungeon cleared the mythic flag")
      assertPaused(world, runtime, notice, "stale Activating inside its grace")

      assert(#graceTimers == 1, "one grace timer is waiting")
      graceTimers[1]()
      assertOpen(world, runtime, "stale Activating expired")
    end
  end)

  RestrictionWorld.Restore(world)
  rawset(_G, "GetInstanceInfo", saved.info)
  rawset(_G, "C_Timer", saved.timer)
  FlavorCompat.hasMythicPlus = saved.mythicPlus
  assert(ok, err)
end
