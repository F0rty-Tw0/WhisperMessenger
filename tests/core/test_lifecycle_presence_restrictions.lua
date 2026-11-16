-- The presence handlers set and read the detection flags on the Bootstrap
-- table's restriction instance. The instance keeps its own flag store here,
-- so a handler that wrote or read fields of the Bootstrap table would miss it.
local RestrictionState = require("tests.helpers.restriction_state")
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local ContentDetector = require("WhisperMessenger.Core.ContentDetector")
local FlavorCompat = require("WhisperMessenger.Core.FlavorCompat")
local RestrictedActions = require("WhisperMessenger.Core.Bootstrap.RestrictedActions")

local function newBootstrap(runtimeFields)
  local calls = { suspend = 0, resume = 0 }
  local runtime = runtimeFields or {}
  runtime.suspend = function()
    calls.suspend = calls.suspend + 1
  end
  runtime.resume = function()
    calls.resume = calls.resume + 1
  end
  local instance = RestrictedActions.New()
  runtime.restrictedActions = instance
  return { restrictions = instance, runtime = runtime }, instance, calls
end

local function deps(presenceCache)
  return {
    getContentDetector = function()
      return ContentDetector
    end,
    getPresenceCache = function()
      return presenceCache
    end,
  }
end

local function standIn(instanceType, difficultyID)
  rawset(_G, "GetInstanceInfo", function()
    return "Somewhere", instanceType, difficultyID
  end)
end

return function()
  local saved = { info = rawget(_G, "GetInstanceInfo"), timer = rawget(_G, "C_Timer"), mythicPlus = FlavorCompat.hasMythicPlus }
  local scheduled = {}
  rawset(_G, "C_Timer", {
    After = function(_delay, fn)
      scheduled[#scheduled + 1] = fn
    end,
  })
  FlavorCompat.hasMythicPlus = true

  local ok, err = pcall(function()
    -- test_entering_a_battleground_sets_the_flags_on_the_instance
    do
      standIn("pvp", 1)
      local Bootstrap, instance = newBootstrap()
      instance.setFlag("encounter", true)
      LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", deps(nil))
      assert(instance.flag("competitive") == true, "a battleground sets the competitive flag on the instance")
      assert(instance.flag("encounter") == false, "entering the world clears the encounter flag on the instance")
      assert(instance.flag("mythic") == false, "a battleground is not Mythic+")
    end

    -- test_entering_a_keystone_dungeon_suspends_once
    do
      standIn("party", 8)
      local Bootstrap, instance, calls = newBootstrap()
      LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", deps(nil))
      LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", deps(nil))
      assert(instance.flag("mythic") == true, "a keystone dungeon sets the mythic flag on the instance")
      assert(calls.suspend == 1, "the second entry sees the flag on the instance, got " .. calls.suspend .. " suspends")
    end

    -- test_leaving_a_keystone_dungeon_resumes
    do
      standIn("none", 0)
      local Bootstrap, instance, calls = newBootstrap()
      instance.setFlag("mythic", true)
      LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", deps(nil))
      assert(calls.resume == 1, "the mythic flag on the instance is what makes the open world a resume, got " .. calls.resume)
      for _, name in ipairs(RestrictionState.NAMES) do
        assert(instance.flag(name) == false, "the open world clears the " .. name .. " flag")
      end
    end

    -- test_login_presence_rebuild_is_skipped_once_the_instance_says_mythic
    do
      standIn("none", 0)
      scheduled = {}
      local rebuilds = 0
      local presenceCache = {
        Rebuild = function()
          rebuilds = rebuilds + 1
        end,
      }
      local Bootstrap, instance = newBootstrap()
      LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", deps(presenceCache))
      instance.setFlag("mythic", true)
      for _, fn in ipairs(scheduled) do
        fn()
      end
      assert(rebuilds == 0, "no presence rebuild after a key started, got " .. rebuilds)
    end

    -- test_roster_update_schedules_no_zone_check_while_the_instance_says_mythic
    do
      scheduled = {}
      local presenceCache = { Invalidate = function() end, RefreshPresence = function() end, GetZone = function() end }
      local armed = { ["wow::a"] = { channel = "WOW", guid = "Player-A", notifyZone = true } }
      local Bootstrap, instance = newBootstrap({ store = { conversations = armed } })
      instance.setFlag("mythic", true)
      LifecycleHandlers.Handle(Bootstrap, "GUILD_ROSTER_UPDATE", deps(presenceCache))
      assert(#scheduled == 0, "no zone check in Mythic+, got " .. #scheduled .. " timers")
    end
  end)

  rawset(_G, "GetInstanceInfo", saved.info)
  rawset(_G, "C_Timer", saved.timer)
  FlavorCompat.hasMythicPlus = saved.mythicPlus
  assert(ok, err)
end
