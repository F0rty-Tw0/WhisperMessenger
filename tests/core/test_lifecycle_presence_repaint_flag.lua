-- A Battle.net friend event marks the open window as owing a full draw
-- (runtime.bnetRepaintPending), before its scan runs, so the status tick
-- still redraws when the scan missed the change or failed half way.

local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")
local ScanWorld = require("tests.helpers.bnet_scan_world")

-- An open window on the real coordinator, sharing its runtime with the
-- friend scan. Returns Bootstrap, world, gameAccounts. world.paints counts
-- full window draws, world.tick() fires the status ticker.
local function makeOpenWindow()
  local gameAccounts = { ScanWorld.WowAccount("Jaina") }
  local runtime = {
    bnetApi = ScanWorld.NewApi(ScanWorld.Account(), gameAccounts),
    store = ScanWorld.Store(),
    availabilityByGUID = {},
    availabilityRequestedAt = {},
    chatApi = {},
  }
  local world = { paints = 0 }
  local shown = false
  local window = {
    frame = {},
    refreshSelection = function()
      world.paints = world.paints + 1
    end,
  }
  function window.frame:IsShown()
    return shown
  end
  function window.frame:Show()
    shown = true
  end
  local coordinator = WindowCoordinator.Create({
    runtime = runtime,
    getWindow = function()
      return window
    end,
    requestAvailability = function() end,
    cTimer = {
      NewTicker = function(_interval, callback)
        world.tick = callback
        return { Cancel = function() end }
      end,
    },
  })
  runtime.isWindowVisible = coordinator.isWindowVisible
  runtime.refreshWindow = coordinator.refreshWindow
  coordinator.setWindowVisible(true)
  return { runtime = runtime }, world, gameAccounts
end

-- deps whose BNetStatus raises while a conversation's fields are applied,
-- once failing.armed is set: the scan stops half way through its loop.
local function makeFailingDeps(failing)
  local BNetStatus = require("WhisperMessenger.Model.ContactEnricher.BNetStatus")
  local failingStatus = setmetatable({
    ApplyGameInfoMetadata = function(...)
      if failing.armed then
        error("secret string compared")
      end
      return BNetStatus.ApplyGameInfoMetadata(...)
    end,
  }, { __index = BNetStatus })
  return {
    loadModule = function(modulePath)
      if string.find(modulePath, "BNetStatus", 1, true) then
        return failingStatus
      end
      return require(modulePath)
    end,
  }
end

return function()
  local savedCTimer = rawget(_G, "C_Timer")

  -- test_friend_event_marks_repaint_pending_before_its_scan_runs
  -- test_scan_marks_repaint_pending_again_after_a_draw_in_between
  do
    local scheduled = {}
    rawset(_G, "C_Timer", {
      After = function(_delay, callback)
        scheduled[#scheduled + 1] = callback
      end,
    })
    local bnetApi = ScanWorld.NewApi(ScanWorld.Account(), { ScanWorld.WowAccount("Jaina") })
    local Bootstrap, refreshes = ScanWorld.Bootstrap(bnetApi, ScanWorld.Store(), true)

    Presence.handleBNetFriendEvent(Bootstrap, { loadModule = require })

    assert(#scheduled == 1 and #refreshes == 0, "test precondition: the scan is deferred")
    assert(Bootstrap.runtime.bnetRepaintPending == true, "the event marks the window before the scan runs")

    Bootstrap.runtime.bnetRepaintPending = nil -- a status tick drew the window in between
    Presence.handleBNetFriendEvent(Bootstrap, { loadModule = require })
    assert(Bootstrap.runtime.bnetRepaintPending == true, "an event during the pending scan marks the window again")

    Bootstrap.runtime.bnetRepaintPending = nil
    scheduled[1]()
    assert(Bootstrap.runtime.bnetRepaintPending == true, "the scan marks the window again before it reads the friend list")
  end

  rawset(_G, "C_Timer", nil) -- scans run synchronously

  -- test_scan_that_changed_something_leaves_nothing_pending
  do
    local Bootstrap, world = makeOpenWindow()
    world.paints = 0

    Presence.handleBNetFriendEvent(Bootstrap, { loadModule = require })

    assert(world.paints == 1, "test precondition: the first scan draws the window")
    assert(Bootstrap.runtime.bnetRepaintPending == nil, "the scan's own draw settles the event")
  end

  -- test_scan_that_changed_nothing_is_repainted_by_the_status_tick
  -- Covers a friend that went away and came back before the scan ran.
  do
    local Bootstrap, world = makeOpenWindow()
    Presence.handleBNetFriendEvent(Bootstrap, { loadModule = require })
    world.paints = 0

    Presence.handleBNetFriendEvent(Bootstrap, { loadModule = require })
    assert(world.paints == 0, "test precondition: the scan saw no change and drew nothing")
    world.tick()

    assert(world.paints == 1, "the status tick must redraw the window, got " .. world.paints .. " draws")
  end

  -- test_scan_that_throws_mid_loop_is_repainted_by_the_status_tick
  do
    local Bootstrap, world, gameAccounts = makeOpenWindow()
    local failing = { armed = false }
    local deps = makeFailingDeps(failing)
    Presence.handleBNetFriendEvent(Bootstrap, deps)
    world.paints = 0

    gameAccounts[1].areaName = "Isle of Dorn"
    failing.armed = true
    local scanned = pcall(Presence.handleBNetFriendEvent, Bootstrap, deps)
    assert(scanned == false and world.paints == 0, "test precondition: the scan raised before it drew anything")
    world.tick()

    assert(world.paints == 1, "the status tick must redraw after a failed scan, got " .. world.paints .. " draws")
  end

  rawset(_G, "C_Timer", savedCTimer)
end
