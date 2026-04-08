local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local LockdownState = require("WhisperMessenger.Core.Bootstrap.LockdownState")

return function()
  local savedGetInstanceInfo = _G.GetInstanceInfo
  local savedCTimer = _G.C_Timer
  local savedCChatInfo = _G.C_ChatInfo

  _G.C_Timer = {
    After = function(_delay, fn)
      fn()
    end,
  }

  local function setLockdown(active)
    _G.C_ChatInfo = {
      InChatMessagingLockdown = function()
        return active
      end,
    }
  end

  local function makeDeps(trace)
    return {
      trace = trace or function() end,
      getContentDetector = function()
        return nil
      end,
      getPresenceCache = function()
        return nil
      end,
    }
  end

  local function makeBootstrap(extra)
    local Bootstrap = extra or {}
    Bootstrap.runtime = Bootstrap.runtime or { suspend = function() end, resume = function() end }
    if Bootstrap.lockdown == nil then
      LockdownState.Initialize(Bootstrap)
    end
    return Bootstrap
  end

  -- -----------------------------------------------------------------------
  -- test_player_entering_world_sets_lockdown_active_in_pvp
  -- -----------------------------------------------------------------------
  do
    setLockdown(true)
    local Bootstrap = makeBootstrap()
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())
    assert(Bootstrap.lockdown.active == true, "should set lockdown.active when entering locked BG")
    assert(Bootstrap.lockdown.source == "PLAYER_ENTERING_WORLD", "source should be PLAYER_ENTERING_WORLD")
  end

  -- -----------------------------------------------------------------------
  -- test_player_entering_world_clears_lockdown_in_open_world
  -- -----------------------------------------------------------------------
  do
    setLockdown(false)
    local Bootstrap = makeBootstrap({
      lockdown = { active = true, since = 1, source = "PLAYER_ENTERING_WORLD" },
    })
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())
    assert(Bootstrap.lockdown.active == false, "should clear lockdown.active when entering open world")
  end

  -- -----------------------------------------------------------------------
  -- test_player_entering_world_sets_lockdown_in_mythic
  -- -----------------------------------------------------------------------
  do
    setLockdown(true)
    local Bootstrap = makeBootstrap()
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())
    assert(Bootstrap.lockdown.active == true, "should set lockdown.active when entering mythic keystone")
  end

  -- -----------------------------------------------------------------------
  -- test_zone_changed_clears_lockdown_when_leaving_pvp
  -- -----------------------------------------------------------------------
  do
    setLockdown(false)
    local Bootstrap = makeBootstrap({
      lockdown = { active = true, since = 1, source = "PLAYER_ENTERING_WORLD" },
    })
    LifecycleHandlers.Handle(Bootstrap, "ZONE_CHANGED_NEW_AREA", makeDeps())
    assert(Bootstrap.lockdown.active == false, "should clear lockdown.active on zone change out of pvp")
  end

  -- -----------------------------------------------------------------------
  -- test_zone_changed_notifies_when_leaving_competitive_after_mythic
  -- Regression: returning to a capital city after a Mythic+ run left the
  -- indicator and banner stuck on, because the zone-change handler updated
  -- the flag but never called the state callback.
  -- -----------------------------------------------------------------------
  do
    setLockdown(false)
    local callbackValue = "unset"
    local runtime = { suspend = function() end, resume = function() end, messagingNotice = "paused" }
    local Bootstrap = makeBootstrap({
      lockdown = { active = true, since = 1, source = "CHALLENGE_MODE_START" },
      runtime = runtime,
      onCompetitiveStateChanged = function(active)
        callbackValue = active
      end,
    })

    LifecycleHandlers.Handle(Bootstrap, "ZONE_CHANGED_NEW_AREA", makeDeps())

    assert(Bootstrap.lockdown.active == false, "lockdown should be cleared")
    assert(
      callbackValue == false,
      "should fire onCompetitiveStateChanged(false) on exit, got: " .. tostring(callbackValue)
    )
    assert(runtime.messagingNotice == nil, "should clear runtime.messagingNotice on exit")
  end

  -- -----------------------------------------------------------------------
  -- test_encounter_start_sets_lockdown_when_locked
  -- -----------------------------------------------------------------------
  do
    setLockdown(true)
    local Bootstrap = makeBootstrap()
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps())

    assert(Bootstrap.lockdown.active == true, "should set lockdown.active on locked ENCOUNTER_START")
    assert(Bootstrap.lockdown.source == "ENCOUNTER_START", "source should be ENCOUNTER_START")
    _G._wmSuspended = nil
  end

  -- -----------------------------------------------------------------------
  -- test_encounter_end_clears_lockdown
  -- -----------------------------------------------------------------------
  do
    setLockdown(false)
    local Bootstrap = makeBootstrap({
      lockdown = { active = true, since = 1, source = "ENCOUNTER_START" },
    })
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps())
    assert(Bootstrap.lockdown.active == false, "should clear lockdown.active on ENCOUNTER_END")
  end

  -- -----------------------------------------------------------------------
  -- test_encounter_start_calls_competitive_state_callback
  -- -----------------------------------------------------------------------
  do
    setLockdown(true)
    local callbackCalled = false
    local callbackValue = nil
    local Bootstrap = makeBootstrap({
      onCompetitiveStateChanged = function(active)
        callbackCalled = true
        callbackValue = active
      end,
    })
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps())

    assert(callbackCalled == true, "should call onCompetitiveStateChanged on ENCOUNTER_START")
    assert(callbackValue == true, "should pass true to onCompetitiveStateChanged on ENCOUNTER_START")
    _G._wmSuspended = nil
  end

  -- -----------------------------------------------------------------------
  -- test_encounter_end_calls_competitive_state_callback_false
  -- -----------------------------------------------------------------------
  do
    setLockdown(false)
    local callbackValue = nil
    local Bootstrap = makeBootstrap({
      lockdown = { active = true, since = 1, source = "ENCOUNTER_START" },
      onCompetitiveStateChanged = function(active)
        callbackValue = active
      end,
    })

    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps())
    assert(
      callbackValue == false,
      "should pass false to onCompetitiveStateChanged when encounter ends and lockdown clears"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_player_entering_world_calls_competitive_state_callback
  -- -----------------------------------------------------------------------
  do
    setLockdown(true)
    local callbackValue = nil
    local Bootstrap = makeBootstrap({
      onCompetitiveStateChanged = function(active)
        callbackValue = active
      end,
    })
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())
    assert(callbackValue == true, "should call onCompetitiveStateChanged=true when entering locked zone")
  end

  -- -----------------------------------------------------------------------
  -- test_encounter_start_sets_messaging_notice
  -- -----------------------------------------------------------------------
  do
    setLockdown(true)
    local runtime = { suspend = function() end, resume = function() end }
    local Bootstrap = makeBootstrap({ runtime = runtime })
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps())

    assert(runtime.messagingNotice ~= nil, "should set runtime.messagingNotice on locked ENCOUNTER_START")
    assert(
      type(runtime.messagingNotice) == "string" and runtime.messagingNotice ~= "",
      "messagingNotice should be a non-empty string"
    )
    _G._wmSuspended = nil
  end

  -- -----------------------------------------------------------------------
  -- test_encounter_end_clears_messaging_notice_when_unlocked
  -- -----------------------------------------------------------------------
  do
    setLockdown(false)
    local runtime = { suspend = function() end, resume = function() end, messagingNotice = "paused" }
    local Bootstrap = makeBootstrap({
      lockdown = { active = true, since = 1, source = "ENCOUNTER_START" },
      runtime = runtime,
    })
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps())
    assert(
      runtime.messagingNotice == nil,
      "should clear runtime.messagingNotice when encounter ends and lockdown clears"
    )
  end

  -- -----------------------------------------------------------------------
  -- test_player_entering_world_sets_messaging_notice_when_locked
  -- -----------------------------------------------------------------------
  do
    setLockdown(true)
    local runtime = { suspend = function() end, resume = function() end }
    local Bootstrap = makeBootstrap({ runtime = runtime })
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())
    assert(runtime.messagingNotice ~= nil, "should set runtime.messagingNotice when entering locked zone")
  end

  -- -----------------------------------------------------------------------
  -- test_player_entering_world_clears_messaging_notice_when_unlocked
  -- -----------------------------------------------------------------------
  do
    setLockdown(false)
    local runtime = { suspend = function() end, resume = function() end, messagingNotice = "paused" }
    local Bootstrap = makeBootstrap({
      lockdown = { active = true, since = 1, source = "PLAYER_ENTERING_WORLD" },
      runtime = runtime,
    })
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", makeDeps())
    assert(runtime.messagingNotice == nil, "should clear runtime.messagingNotice when entering unlocked world")
  end

  -- -----------------------------------------------------------------------
  -- test_encounter_start_calls_syncChatFilters
  -- -----------------------------------------------------------------------
  do
    setLockdown(true)
    local syncCalled = false
    local Bootstrap = makeBootstrap({
      syncChatFilters = function()
        syncCalled = true
      end,
    })
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps())
    assert(syncCalled == true, "should call syncChatFilters on ENCOUNTER_START")
    _G._wmSuspended = nil
  end

  -- -----------------------------------------------------------------------
  -- test_encounter_end_calls_syncChatFilters
  -- -----------------------------------------------------------------------
  do
    setLockdown(false)
    local syncCalled = false
    local Bootstrap = makeBootstrap({
      lockdown = { active = true, since = 1, source = "ENCOUNTER_START" },
      syncChatFilters = function()
        syncCalled = true
      end,
    })
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_END", makeDeps())
    assert(syncCalled == true, "should call syncChatFilters on ENCOUNTER_END")
  end

  -- -----------------------------------------------------------------------
  -- test_encounter_start_in_normal_raid_does_not_lock
  -- Regression: ENCOUNTER_START fires for ALL raid/dungeon encounters
  -- including LFR/Normal/Heroic raids and non-mythic dungeons. The lock
  -- indicator and "Whispers paused" banner should only appear when Blizzard
  -- actually has chat locked, not on every boss pull in a normal raid.
  -- -----------------------------------------------------------------------
  do
    setLockdown(false)
    local callbackValue = "unset"
    local runtime = { suspend = function() end, resume = function() end }
    local Bootstrap = makeBootstrap({
      runtime = runtime,
      onCompetitiveStateChanged = function(active)
        callbackValue = active
      end,
    })
    LifecycleHandlers.Handle(Bootstrap, "ENCOUNTER_START", makeDeps())

    assert(
      Bootstrap.lockdown.active == false,
      "should NOT set lockdown.active in non-locked encounter (e.g. Normal raid)"
    )
    assert(runtime.messagingNotice == nil, "should NOT set messagingNotice in non-locked encounter")
    assert(callbackValue == "unset", "should NOT fire onCompetitiveStateChanged in non-locked encounter")
  end

  rawset(_G, "GetInstanceInfo", savedGetInstanceInfo)
  _G.C_Timer = savedCTimer
  _G.C_ChatInfo = savedCChatInfo
end
