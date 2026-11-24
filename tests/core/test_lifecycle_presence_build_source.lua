-- /wmsg perf counts the contact rebuilds a Battle.net friend scan causes
-- under "bnetScan".

local FakeScanResolver = require("tests.helpers.fake_scan_resolver")
local Presence = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.Presence")
local CharacterMergeMap = require("WhisperMessenger.Model.CharacterMergeMap")
local PerfCounters = require("WhisperMessenger.Util.PerfCounters")

local function makeDeps()
  local friends = {
    ["Friend#1234"] = {
      bnetAccountID = 42,
      accountInfo = { battleTag = "Friend#1234", gameAccountInfo = { characterName = "Newchar", realmName = "Area52" } },
    },
  }
  return {
    loadModule = function(modulePath)
      if string.find(modulePath, "BNetResolver", 1, true) then
        return FakeScanResolver.New(function()
          return friends
        end)
      end
      return require(modulePath)
    end,
  }
end

-- runtime.refreshWindow counts one snapshot build, as the cache does.
local function makeBootstrap(visible)
  return {
    runtime = {
      bnetApi = {},
      characterMerges = CharacterMergeMap.Ensure({}),
      store = { conversations = { ["bnet::friend"] = { channel = "BN", battleTag = "Friend#1234", displayName = "Friend#1234", messages = {} } } },
      isWindowVisible = function()
        return visible
      end,
      refreshWindow = function()
        PerfCounters.IncrementBySource("snapshotBuilds")
      end,
    },
  }
end

return function()
  -- Without C_Timer the scan debounce runs at once.
  local savedCTimer = rawget(_G, "C_Timer")
  rawset(_G, "C_Timer", nil)

  -- test_hidden_bnet_scan_builds_count_as_bnet_scan
  do
    PerfCounters.Reset()

    Presence.handleBNetFriendEvent(makeBootstrap(false), makeDeps())

    assert(PerfCounters.Get("snapshotBuilds") == 1, "test precondition: the scan refreshed once")
    assert(PerfCounters.GetSource("snapshotBuilds", "bnetScan") == 1, "the hidden scan's build counts as bnetScan")
  end

  -- test_visible_bnet_scan_builds_count_as_bnet_scan
  do
    PerfCounters.Reset()

    Presence.handleBNetFriendEvent(makeBootstrap(true), makeDeps())

    assert(PerfCounters.Get("snapshotBuilds") == 1, "test precondition: the scan refreshed once")
    assert(PerfCounters.GetSource("snapshotBuilds", "bnetScan") == 1, "the open window's scan build counts as bnetScan")
  end

  rawset(_G, "C_Timer", savedCTimer)
end
