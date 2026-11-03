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
  LifecycleHandlers.Handle(Bootstrap, "BN_FRIEND_INFO_CHANGED", bnetDeps({ ["Anduin#1"] = { bnetAccountID = 7, accountInfo = inWoW("Azj-Kahet") } }))
  -- The alert hides the BattleTag number, like every other on-screen name.
  assert(
    #lines == 2 and string.find(lines[2], "Anduin changed zone from Dornogal to Azj-Kahet.", 1, true),
    "Battle.net alert: " .. tostring(lines[2])
  )
  assert(anduin.notifyZone == nil, "Battle.net one-shot: disarmed")

  -- test_no_runtime_is_harmless
  LifecycleHandlers.Handle({}, "GUILD_ROSTER_UPDATE", guildDeps)

  rawset(_G, "DEFAULT_CHAT_FRAME", nil)
  rawset(_G, "PlaySound", nil)
  _G.C_Timer = savedTimer
end
