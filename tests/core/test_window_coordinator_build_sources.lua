-- /wmsg perf splits snapshotBuilds by what asked for the contact rebuild.
-- Each coordinator entry point names its source; any other caller counts
-- as "other".

local WindowCoordinator = require("WhisperMessenger.Core.Bootstrap.WindowCoordinator")
local PerfCounters = require("WhisperMessenger.Util.PerfCounters")

-- Returns coordinator, runtime, world. Every buildContacts call counts one
-- snapshot build, as the snapshot cache does. world.tick() fires the status
-- ticker; timers run their callback at once.
local function makeCoordinator(shown)
  local world = {}
  local window = {
    frame = {
      IsShown = function()
        return shown
      end,
      Show = function()
        shown = true
      end,
    },
    refreshSelection = function() end,
  }
  local runtime = { availabilityByGUID = {}, availabilityRequestedAt = {}, chatApi = {}, store = { conversations = {} } }
  local coordinator = WindowCoordinator.Create({
    runtime = runtime,
    buildContacts = function()
      PerfCounters.IncrementBySource("snapshotBuilds")
      return {}
    end,
    getWindow = function()
      return window
    end,
    requestAvailability = function() end,
    cTimer = {
      NewTicker = function(_interval, callback)
        world.tick = callback
        return { Cancel = function() end }
      end,
      After = function(_delay, callback)
        callback()
      end,
    },
  })
  PerfCounters.Reset()
  return coordinator, runtime, world
end

local function sourceCount(source)
  return PerfCounters.GetSource("snapshotBuilds", source)
end

local function assertOnly(source, label)
  local total = PerfCounters.Get("snapshotBuilds")
  assert(total > 0, label .. ": test precondition, no build ran")
  assert(sourceCount(source) == total, label .. ": every build counts as " .. source .. ", got " .. sourceCount(source) .. " of " .. total)
end

return function()
  -- test_status_tick_builds_count_as_ticker
  do
    local coordinator, _runtime, world = makeCoordinator(false)
    coordinator.setWindowVisible(true)
    PerfCounters.Reset()

    world.tick()

    assertOnly("ticker", "status tick")
  end

  -- test_status_tick_full_redraw_counts_as_ticker
  do
    local coordinator, runtime, world = makeCoordinator(false)
    coordinator.setWindowVisible(true)
    PerfCounters.Reset()
    runtime.bnetRepaintPending = true

    world.tick()

    assertOnly("ticker", "status tick redraw")
  end

  -- test_icon_surface_update_counts_as_icon_surfaces
  do
    local coordinator = makeCoordinator(false)

    coordinator.updateIconSurfaces()

    assertOnly("iconSurfaces", "icon surfaces")
  end

  -- test_whisper_flush_counts_as_whisper_flush
  do
    local coordinator = makeCoordinator(false)

    coordinator.scheduleWhisperRefresh("wow::WOW::arthas")

    assertOnly("whisperFlush", "whisper flush")
  end

  -- test_whisper_flush_forced_full_by_bnet_repaint_counts_apart
  do
    local coordinator, runtime = makeCoordinator(false)
    runtime.bnetRepaintPending = true

    coordinator.scheduleWhisperRefresh("wow::WOW::arthas")

    assertOnly("whisperBnetRepaint", "whisper flush with a pending repaint")
  end

  -- test_incoming_group_refresh_counts_as_incoming
  do
    local coordinator = makeCoordinator(true)

    coordinator.scheduleIncomingRefresh("party::me")

    assertOnly("incoming", "incoming refresh")
  end

  -- test_availability_refresh_counts_as_availability
  do
    local coordinator = makeCoordinator(true)

    coordinator.scheduleAvailabilityRefresh("Player-1")

    assertOnly("availability", "availability refresh")
  end

  -- test_window_open_counts_as_window_show
  do
    local coordinator = makeCoordinator(false)

    coordinator.setWindowVisible(true)

    assertOnly("windowShow", "window open")
  end

  -- test_latest_unread_search_counts_as_find_unread
  do
    local coordinator = makeCoordinator(false)

    coordinator.findLatestUnreadKey()

    assertOnly("findUnread", "latest unread search")
  end

  -- test_plain_refresh_counts_as_other
  do
    local coordinator = makeCoordinator(false)

    coordinator.refreshWindow()

    assertOnly("other", "plain refresh")
  end
end
