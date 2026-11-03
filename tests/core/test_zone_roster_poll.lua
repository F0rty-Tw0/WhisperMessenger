local ZoneRosterPoll = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers.ZoneRosterPoll")
local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local ContentDetector = require("WhisperMessenger.Core.ContentDetector")
local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

-- Guild zones only arrive with GUILD_ROSTER_UPDATE, which the game sends
-- after a roster request. While a guild/community contact has "Notify when
-- they change zone" on, the roster is asked for once a minute; never
-- otherwise.

return function()
  local savedTimer, savedIsInGuild, savedGuildInfo = _G.C_Timer, _G.IsInGuild, _G.C_GuildInfo
  local scheduled, requests = {}, 0
  _G.C_Timer = {
    After = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end,
  }
  rawset(_G, "IsInGuild", function()
    return true
  end)
  _G.C_GuildInfo = {
    GuildRoster = function()
      requests = requests + 1
    end,
  }

  local jaina = { channel = "WOW", guid = "Player-JAINA" }
  local runtime = { store = { conversations = { ["wow::jaina"] = jaina } } }

  -- test_nothing_armed_asks_nothing
  ZoneRosterPoll.Start(runtime)
  assert(requests == 0 and #scheduled == 0, "nothing armed: no request, no timer")

  -- test_armed_bnet_friend_asks_nothing
  local anduin = { channel = "BN", guid = "Player-ANDUIN", notifyZone = true }
  runtime.store.conversations["bnet::anduin"] = anduin
  ZoneRosterPoll.Start(runtime)
  assert(requests == 0 and #scheduled == 0, "Battle.net zones come from the friend list, not the roster")

  -- test_armed_guild_member_asks_now_and_every_minute
  jaina.notifyZone = true
  ZoneRosterPoll.Start(runtime)
  assert(requests == 1, "asks right away")
  assert(#scheduled == 1 and scheduled[1].delay == ZoneRosterPoll.INTERVAL_SECONDS, "next ask in one interval")
  assert(ZoneRosterPoll.INTERVAL_SECONDS == 60, "once a minute")

  -- test_start_while_running_asks_nothing_more
  ZoneRosterPoll.Start(runtime)
  assert(requests == 1 and #scheduled == 1, "already running: no extra request or timer")

  scheduled[1].fn()
  assert(requests == 2 and #scheduled == 2, "tick asks again and schedules the next one")

  -- test_no_request_in_mythic_content
  runtime.isMythicLockdown = function()
    return true
  end
  scheduled[2].fn()
  assert(requests == 2 and #scheduled == 3, "mythic content: no request, the poll keeps waiting")
  runtime.isMythicLockdown = nil

  -- test_stops_once_nothing_is_armed
  jaina.notifyZone = nil
  scheduled[3].fn()
  assert(requests == 2 and #scheduled == 3, "nothing armed: no request, no next tick")

  -- test_rearming_starts_again
  jaina.notifyZone = true
  ZoneRosterPoll.Start(runtime)
  assert(requests == 3 and #scheduled == 4, "stopped poll restarts on the next arm")

  -- test_without_timers_asks_once_per_start
  _G.C_Timer = nil
  local bare = { store = { conversations = { k = { channel = "WOW", guid = "Player-X", notifyZone = true } } } }
  ZoneRosterPoll.Start(bare)
  assert(requests == 4 and bare.zoneRosterPollPending ~= true, "no timers: one request, nothing left pending")

  -- test_no_runtime_is_harmless
  ZoneRosterPoll.Start(nil)
  ZoneRosterPoll.Start({})

  -- test_entering_the_world_starts_the_poll_for_saved_watches
  do
    local savedGetInstanceInfo = _G.GetInstanceInfo
    rawset(_G, "GetInstanceInfo", function()
      return "Orgrimmar", "none", 0
    end)
    _G.C_Timer = {
      After = function(delay, fn)
        scheduled[#scheduled + 1] = { delay = delay, fn = fn }
      end,
    }
    local saved = { channel = "WOW", guid = "Player-SAVED", notifyZone = true }
    local Bootstrap = { runtime = { store = { conversations = { k = saved } } } }
    local before = requests
    LifecycleHandlers.Handle(Bootstrap, "PLAYER_ENTERING_WORLD", {
      getContentDetector = function()
        return ContentDetector
      end,
      getPresenceCache = function()
        return { Rebuild = function() end }
      end,
    })
    assert(requests == before + 1, "a watch saved from last session asks for the roster on login")
    assert(Bootstrap.runtime.zoneRosterPollPending == true, "and keeps polling")
    rawset(_G, "GetInstanceInfo", savedGetInstanceInfo)
  end

  -- test_arming_from_the_contact_menu_starts_the_poll
  do
    local member = { channel = "WOW", guid = "Player-MENU" }
    local menuRuntime = { store = { conversations = { k = member } } }
    local callbacks = WindowCallbacks.Create({ runtime = menuRuntime, characterState = {} })
    local before = requests
    callbacks.onUpdatePrefs({ conversationKey = "k" }, { notifyZone = true })
    assert(requests == before + 1, "arming asks for the roster right away")
    assert(menuRuntime.zoneRosterPollPending == true, "and keeps polling")
  end

  _G.C_Timer, _G.IsInGuild, _G.C_GuildInfo = savedTimer, savedIsInGuild, savedGuildInfo
end
