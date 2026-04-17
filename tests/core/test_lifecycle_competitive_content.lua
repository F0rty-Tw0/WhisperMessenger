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

  -- test_player_entering_world_sets_competitive_in_pvp

  do
    rawset(_G, "GetInstanceInfo", function()
      return "Warsong Gulch", "pvp", 1
    end)

    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inCompetitiveContent == true, "should set _inCompetitiveContent=true when entering battleground")
  end

  -- test_player_entering_world_sets_competitive_in_arena

  do
    rawset(_G, "GetInstanceInfo", function()
      return "Nagrand Arena", "arena", 1
    end)

    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inCompetitiveContent == true, "should set _inCompetitiveContent=true when entering arena")
  end

  -- test_player_entering_world_clears_competitive_in_open_world

  do
    rawset(_G, "GetInstanceInfo", function()
      return "Eastern Kingdoms", "none", 0
    end)

    local Bootstrap = { _inCompetitiveContent = true, runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inCompetitiveContent == false, "should clear _inCompetitiveContent when entering open world")
  end

  -- test_player_entering_world_tracks_mythic_separately
  -- Mythic+ sets _inMythicContent (not _inCompetitiveContent) so the hard
  -- lockdown is driven by MythicSuspendController / RestrictedActions and
  -- fires only when the key is actually started, not on mere zone entry.

  do
    rawset(_G, "GetInstanceInfo", function()
      return "Dungeon", "party", 8
    end)

    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(Bootstrap._inMythicContent == true, "should set _inMythicContent=true for mythic keystone")
    assert(
      Bootstrap._inCompetitiveContent == false,
      "should NOT set _inCompetitiveContent for mythic keystone (mythic is separate)"
    )
  end

  -- test_zone_changed_clears_competitive_when_leaving_pvp

  do
    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)

    local Bootstrap = { _inCompetitiveContent = true }
    LifecycleHandlers.Handle(Bootstrap, "ZONE_CHANGED_NEW_AREA", makeDeps())

    assert(Bootstrap._inCompetitiveContent == false, "should clear _inCompetitiveContent on zone change out of pvp")
  end

  -- test_encounter_start_sets_in_encounter

  do
    local Bootstrap = { runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps())

    assert(Bootstrap._inEncounter == true, "should set _inEncounter=true on ENCOUNTER_START")
  end

  -- test_encounter_end_clears_in_encounter

  do
    local Bootstrap = { _inEncounter = true, runtime = { suspend = function() end, resume = function() end } }
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps())

    assert(Bootstrap._inEncounter == false, "should clear _inEncounter on ENCOUNTER_END")
  end

  -- test_encounter_start_calls_competitive_state_callback

  do
    local callbackCalled = false
    local callbackValue = nil
    local Bootstrap = {
      runtime = { suspend = function() end, resume = function() end },
      onCompetitiveStateChanged = function(active)
        callbackCalled = true
        callbackValue = active
      end,
    }
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps())

    assert(callbackCalled == true, "should call onCompetitiveStateChanged on ENCOUNTER_START")
    assert(callbackValue == true, "should pass true to onCompetitiveStateChanged on ENCOUNTER_START")
  end

  -- test_encounter_end_calls_competitive_state_callback_false

  do
    local callbackValue = nil
    local Bootstrap = {
      _inEncounter = true,
      runtime = { suspend = function() end, resume = function() end },
      onCompetitiveStateChanged = function(active)
        callbackValue = active
      end,
    }

    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)

    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps())

    assert(
      callbackValue == false,
      "should pass false to onCompetitiveStateChanged when encounter ends outside competitive content"
    )
  end

  -- test_encounter_end_still_competitive_in_bg

  do
    local callbackValue = nil
    local Bootstrap = {
      _inEncounter = true,
      _inCompetitiveContent = true,
      runtime = { suspend = function() end, resume = function() end },
      onCompetitiveStateChanged = function(active)
        callbackValue = active
      end,
    }

    rawset(_G, "GetInstanceInfo", function()
      return "Warsong Gulch", "pvp", 1
    end)

    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps())

    assert(
      callbackValue == true,
      "should pass true to onCompetitiveStateChanged when encounter ends but still in competitive zone"
    )
  end

  -- test_player_entering_world_calls_competitive_state_callback

  do
    local callbackValue = nil
    local Bootstrap = {
      runtime = { suspend = function() end, resume = function() end },
      onCompetitiveStateChanged = function(active)
        callbackValue = active
      end,
    }

    rawset(_G, "GetInstanceInfo", function()
      return "Warsong Gulch", "pvp", 1
    end)

    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(callbackValue == true, "should call onCompetitiveStateChanged=true when entering BG")
  end

  -- test_encounter_start_sets_messaging_notice

  do
    local runtime = { suspend = function() end, resume = function() end }
    local Bootstrap = { runtime = runtime }
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps())

    assert(runtime.messagingNotice ~= nil, "should set runtime.messagingNotice on ENCOUNTER_START")
    assert(
      type(runtime.messagingNotice) == "string" and runtime.messagingNotice ~= "",
      "messagingNotice should be a non-empty string"
    )
  end

  -- test_encounter_end_clears_messaging_notice_outside_competitive

  do
    local runtime = { suspend = function() end, resume = function() end, messagingNotice = "paused" }
    local Bootstrap = { _inEncounter = true, runtime = runtime }

    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)

    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps())

    assert(
      runtime.messagingNotice == nil,
      "should clear runtime.messagingNotice when encounter ends outside competitive zone"
    )
  end

  -- test_encounter_end_keeps_messaging_notice_in_bg

  do
    local runtime = { suspend = function() end, resume = function() end, messagingNotice = "paused" }
    local Bootstrap = { _inEncounter = true, _inCompetitiveContent = true, runtime = runtime }

    rawset(_G, "GetInstanceInfo", function()
      return "Warsong Gulch", "pvp", 1
    end)

    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps())

    assert(
      runtime.messagingNotice ~= nil,
      "should keep runtime.messagingNotice when encounter ends but still in competitive zone"
    )
  end

  -- test_player_entering_world_sets_messaging_notice_in_bg

  do
    local runtime = { suspend = function() end, resume = function() end }
    local Bootstrap = { runtime = runtime }

    rawset(_G, "GetInstanceInfo", function()
      return "Warsong Gulch", "pvp", 1
    end)

    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(runtime.messagingNotice ~= nil, "should set runtime.messagingNotice when entering battleground")
  end

  -- test_player_entering_world_clears_messaging_notice_in_open_world

  do
    local runtime = { suspend = function() end, resume = function() end, messagingNotice = "paused" }
    local Bootstrap = { runtime = runtime }

    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)

    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())

    assert(runtime.messagingNotice == nil, "should clear runtime.messagingNotice when entering open world")
  end

  -- test_encounter_start_calls_syncChatFilters

  do
    local syncCalled = false
    local Bootstrap = {
      runtime = { suspend = function() end, resume = function() end },
      syncChatFilters = function()
        syncCalled = true
      end,
    }
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps())

    assert(syncCalled == true, "should call syncChatFilters on ENCOUNTER_START")
  end

  -- test_encounter_end_calls_syncChatFilters

  do
    local syncCalled = false
    local Bootstrap = {
      _inEncounter = true,
      runtime = { suspend = function() end, resume = function() end },
      syncChatFilters = function()
        syncCalled = true
      end,
    }

    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)

    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps())

    assert(syncCalled == true, "should call syncChatFilters on ENCOUNTER_END")
  end

  rawset(_G, "GetInstanceInfo", savedGetInstanceInfo)
  _G.C_Timer = savedCTimer
end
