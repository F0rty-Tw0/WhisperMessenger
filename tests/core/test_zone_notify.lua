local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local Localization = require("WhisperMessenger.Locale.Localization")

-- Notify when they change zone: driven by the events presence already uses.
-- Guild/community members on roster events (one member read per armed
-- contact), Battle.net friends on the debounced friend-list refresh.

local function fakePresenceCache(members)
  local reads = {}
  return {
    reads = reads,
    Invalidate = function() end,
    RefreshPresence = function(guid)
      reads[#reads + 1] = guid
      local member = members[guid]
      return member and member.presence or nil
    end,
    GetZone = function(guid)
      local member = members[guid]
      return member and member.zone or nil
    end,
  }
end

local function bnetDeps(friendMap)
  return {
    loadModule = function(modulePath)
      if string.find(modulePath, "BNetResolver", 1, true) then
        return {
          ScanFriendList = function()
            return friendMap
          end,
        }
      end
      return require(modulePath)
    end,
  }
end

local function inWoW(zone)
  return { gameAccountInfo = { characterName = "Anduin", isOnline = true, areaName = zone } }
end

return function()
  Localization.Configure({ language = "enUS" })
  local lines, sounds, refreshes = {}, 0, 0
  rawset(_G, "DEFAULT_CHAT_FRAME", {
    AddMessage = function(_, text)
      lines[#lines + 1] = text
    end,
  })
  rawset(_G, "PlaySound", function()
    sounds = sounds + 1
  end)
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil

  local members = { ["Player-JAINA"] = { presence = "online", zone = "Stormwind City" } }
  local cache = fakePresenceCache(members)
  local guildDeps = {
    getPresenceCache = function()
      return cache
    end,
  }
  local jaina = { channel = "WOW", displayName = "Jaina-Realm", guid = "Player-JAINA", notifyZone = true }
  local thrall = { channel = "WOW", displayName = "Thrall-Realm", guid = "Player-THRALL" }
  local runtime = {
    accountState = { settings = { playSoundOnWhisper = true } },
    store = { conversations = { ["wow::jaina"] = jaina, ["wow::thrall"] = thrall } },
    refreshWindow = function()
      refreshes = refreshes + 1
    end,
  }
  local Bootstrap = { runtime = runtime }

  -- test_first_roster_update_only_records_the_baseline
  LifecycleHandlers.Handle(Bootstrap, "GUILD_ROSTER_UPDATE", guildDeps)
  assert(#lines == 0 and sounds == 0, "baseline: no alert")
  assert(jaina.notifyZoneFrom == "Stormwind City", "baseline recorded")
  assert(#cache.reads == 1 and cache.reads[1] == "Player-JAINA", "only armed contacts are read")

  -- test_offline_member_keeps_it_armed
  members["Player-JAINA"].presence = "offline"
  members["Player-JAINA"].zone = "Orgrimmar"
  LifecycleHandlers.Handle(Bootstrap, "GUILD_ROSTER_UPDATE", guildDeps)
  assert(#lines == 0, "offline: the last stored zone is not a live zone, no alert")
  assert(jaina.notifyZone == true, "offline keeps it armed")

  -- test_guild_member_zone_change_alerts_once
  members["Player-JAINA"].presence = "online"
  LifecycleHandlers.Handle(Bootstrap, "CLUB_MEMBER_UPDATED", guildDeps)
  assert(#lines == 1, "one chat line, got " .. #lines)
  assert(string.find(lines[1], "Jaina-Realm changed zone from Stormwind City to Orgrimmar.", 1, true), "names both zones: " .. lines[1])
  assert(string.find(lines[1], "Whisper Messenger", 1, true), "uses the addon chat prefix")
  assert(sounds == 1, "notification sound played")
  assert(jaina.notifyZone == nil, "one-shot: disarmed")
  assert(refreshes == 1, "window refreshed so the menu tick clears")
  members["Player-JAINA"].zone = "Durotar"
  LifecycleHandlers.Handle(Bootstrap, "GUILD_ROSTER_UPDATE", guildDeps)
  assert(#lines == 1, "disarmed: no second alert")

  -- test_no_presence_cache_is_harmless
  LifecycleHandlers.Handle(Bootstrap, "GUILD_ROSTER_UPDATE", { getPresenceCache = function() end })

  -- test_bnet_friend_zone_change_alerts_once
  local anduin = { channel = "BN", displayName = "Anduin#1", battleTag = "Anduin#1", notifyZone = true }
  runtime.store.conversations = { ["bnet::anduin"] = anduin }
  runtime.bnetApi = {}
  runtime.playerInfoByGUID = {}
  LifecycleHandlers.Handle(Bootstrap, "BN_FRIEND_INFO_CHANGED", bnetDeps({ ["Anduin#1"] = { bnetAccountID = 7, accountInfo = inWoW("Dornogal") } }))
  assert(#lines == 1 and anduin.notifyZoneFrom == "Dornogal", "Battle.net baseline, no alert")
  LifecycleHandlers.Handle(Bootstrap, "BN_FRIEND_INFO_CHANGED", bnetDeps({ ["Anduin#1"] = { bnetAccountID = 7, accountInfo = {} } }))
  assert(#lines == 1 and anduin.notifyZone == true, "left WoW: no alert, still armed")
  -- test_bnet_area_without_a_character_is_not_a_zone
  -- Outside WoW the game account keeps its last areaName; no character means stale.
  local stale = { gameAccountInfo = { isOnline = true, areaName = "Valdrakken" } }
  LifecycleHandlers.Handle(Bootstrap, "BN_FRIEND_INFO_CHANGED", bnetDeps({ ["Anduin#1"] = { bnetAccountID = 7, accountInfo = stale } }))
  assert(#lines == 1 and anduin.notifyZone == true, "areaName without a character: no alert, still armed")
  LifecycleHandlers.Handle(Bootstrap, "BN_FRIEND_INFO_CHANGED", bnetDeps({ ["Anduin#1"] = { bnetAccountID = 7, accountInfo = inWoW("Azj-Kahet") } }))
  -- The alert hides the BattleTag number, like every other on-screen name.
  assert(
    #lines == 2 and string.find(lines[2], "Anduin changed zone from Dornogal to Azj-Kahet.", 1, true),
    "Battle.net alert: " .. tostring(lines[2])
  )
  assert(anduin.notifyZone == nil, "Battle.net one-shot: disarmed")

  -- test_no_runtime_is_harmless
  LifecycleHandlers.Handle({}, "GUILD_ROSTER_UPDATE", guildDeps)

  -- test_armed_bnet_friend_with_a_guid_is_not_read_from_the_roster
  local bnetCache = fakePresenceCache({ ["Player-ANDUIN"] = { presence = "online", zone = "Dornogal" } })
  runtime.store.conversations = { ["bnet::anduin"] = { channel = "BN", guid = "Player-ANDUIN", notifyZone = true } }
  LifecycleHandlers.Handle(Bootstrap, "GUILD_ROSTER_UPDATE", {
    getPresenceCache = function()
      return bnetCache
    end,
  })
  assert(#bnetCache.reads == 0, "Battle.net zones come from the friend list: 0 roster reads, got " .. #bnetCache.reads)

  -- test_armed_contact_outside_every_roster_rescans_once
  -- Left the guild: each roster poll marks presence stale, but only the
  -- first miss pays for a full guild/community rescan.
  local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
  local clock, rescans = 0, 0
  PresenceCache._initForTest({
    GetGuildClubId = function()
      return 1
    end,
    GetSubscribedClubs = function()
      return {}
    end,
    GetClubMembers = function()
      rescans = rescans + 1
      return { 1 }
    end,
    GetMemberInfo = function()
      return { guid = "Player-OTHER", presence = 1, zone = "Dornogal" }
    end,
  }, {
    now = function()
      return clock
    end,
  })
  rescans = 0
  runtime.store.conversations = { ["wow::gone"] = { channel = "WOW", guid = "Player-GONE", notifyZone = true } }
  local realDeps = {
    getPresenceCache = function()
      return PresenceCache
    end,
  }
  for _ = 1, 4 do
    clock = clock + 300
    LifecycleHandlers.Handle(Bootstrap, "GUILD_ROSTER_UPDATE", realDeps)
  end
  assert(rescans == 1, "one rescan for a contact in no roster, got " .. rescans)
  PresenceCache._reset()

  -- test_roster_burst_checks_zones_once_after_it
  -- Roster events come in bursts: presence goes stale at once, the zone
  -- check runs once, 2 s after the first event.
  local scheduled = {}
  _G.C_Timer = {
    After = function(delay, fn)
      scheduled[#scheduled + 1] = { delay = delay, fn = fn }
    end,
  }
  local invalidations = 0
  local burstCache = fakePresenceCache({ ["Player-JAINA"] = { presence = "online", zone = "Dalaran" } })
  burstCache.Invalidate = function()
    invalidations = invalidations + 1
  end
  runtime.store.conversations = { ["wow::jaina"] = { channel = "WOW", guid = "Player-JAINA", notifyZone = true } }
  local burstDeps = {
    getPresenceCache = function()
      return burstCache
    end,
  }
  for _ = 1, 3 do
    LifecycleHandlers.Handle(Bootstrap, "GUILD_ROSTER_UPDATE", burstDeps)
  end
  assert(invalidations == 3, "every event marks presence stale right away")
  assert(#burstCache.reads == 0, "no member read during the burst, got " .. #burstCache.reads)
  assert(#scheduled == 1 and scheduled[1].delay == 2, "one deferred zone check per burst")
  scheduled[1].fn()
  assert(#burstCache.reads == 1, "the deferred check reads the armed member once")
  LifecycleHandlers.Handle(Bootstrap, "GUILD_ROSTER_UPDATE", burstDeps)
  assert(#scheduled == 2, "the next burst schedules its own check")

  rawset(_G, "DEFAULT_CHAT_FRAME", nil)
  rawset(_G, "PlaySound", nil)
  _G.C_Timer = savedTimer
end
