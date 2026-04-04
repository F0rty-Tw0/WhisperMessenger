local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local ContentDetector = require("WhisperMessenger.Core.ContentDetector")

return function()
  local savedGetInstanceInfo = _G.GetInstanceInfo
  local savedCTimer = _G.C_Timer

  _G.C_Timer = {
    After = function(_delay, fn)
      fn()
    end,
  }

  local function makeDeps(trace)
    return {
      trace = trace or function() end,
      getContentDetector = function()
        return ContentDetector
      end,
      getPresenceCache = function()
        return nil
      end,
    }
  end

  -- -----------------------------------------------------------------------
  -- test_player_entering_world_sets_competitive_in_pvp
  -- -----------------------------------------------------------------------
  do
    rawset(_G, "GetInstanceInfo", function()
      return "Warsong Gulch", "pvp", 1
    end)

    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inCompetitiveContent == true, "should set _inCompetitiveContent=true when entering battleground")
  end

  -- -----------------------------------------------------------------------
  -- test_player_entering_world_sets_competitive_in_arena
  -- -----------------------------------------------------------------------
  do
    rawset(_G, "GetInstanceInfo", function()
      return "Nagrand Arena", "arena", 1
    end)

    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inCompetitiveContent == true, "should set _inCompetitiveContent=true when entering arena")
  end

  -- -----------------------------------------------------------------------
  -- test_player_entering_world_clears_competitive_in_open_world
  -- -----------------------------------------------------------------------
  do
    rawset(_G, "GetInstanceInfo", function()
      return "Eastern Kingdoms", "none", 0
    end)

    local Bootstrap = { _inCompetitiveContent = true, runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inCompetitiveContent == false, "should clear _inCompetitiveContent when entering open world")
  end

  -- -----------------------------------------------------------------------
  -- test_player_entering_world_sets_competitive_in_mythic
  -- -----------------------------------------------------------------------
  do
    rawset(_G, "GetInstanceInfo", function()
      return "Dungeon", "party", 8
    end)

    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inCompetitiveContent == true, "should set _inCompetitiveContent=true for mythic keystone")
  end

  -- -----------------------------------------------------------------------
  -- test_zone_changed_clears_competitive_when_leaving_pvp
  -- -----------------------------------------------------------------------
  do
    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)

    local Bootstrap = { _inCompetitiveContent = true }
    LifecycleHandlers.Handle(Bootstrap, "ZONE_CHANGED_NEW_AREA", makeDeps())

    assert(Bootstrap._inCompetitiveContent == false, "should clear _inCompetitiveContent on zone change out of pvp")
  end

  rawset(_G, "GetInstanceInfo", savedGetInstanceInfo)
  _G.C_Timer = savedCTimer
end
