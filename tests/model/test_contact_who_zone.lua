local AvailabilityEnricher = require("WhisperMessenger.Model.ContactEnricher.AvailabilityEnricher")
local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local SeenZone = require("WhisperMessenger.Model.SeenZone")
local DisplayName = require("WhisperMessenger.Util.DisplayName")

local function makeMockClubApi(guildMembers)
  return {
    GetGuildClubId = function()
      return 1
    end,
    GetSubscribedClubs = function()
      return {}
    end,
    GetClubMembers = function(_clubId)
      local ids = {}
      for i = 1, #guildMembers do
        ids[i] = i
      end
      return ids
    end,
    GetMemberInfo = function(_clubId, memberId)
      return guildMembers[memberId]
    end,
  }
end

local function enrich(item)
  AvailabilityEnricher.EnrichContactsAvailability({ item }, { availabilityByGUID = {}, store = { conversations = {} } })
  return item
end

return function()
  rawset(_G, "time", rawget(_G, "time") or os.time)
  DisplayName.Configure({ showPlayerLevels = true })

  -- test_wow_item_with_guid_and_no_live_zone_gets_who_zone
  do
    PresenceCache._reset()
    SeenZone._reset()
    SeenZone.Record("Someone-Realm", "Stormwind", 1000)
    local item = enrich({ channel = "WOW", displayName = "Someone-Realm", guid = "Player-1-AAA" })
    assert(item.whoArea == "Stormwind", "got " .. tostring(item.whoArea))
    assert(item.whoAreaAt == 1000, "got " .. tostring(item.whoAreaAt))
    assert(item.areaName == nil, "areaName stays untouched, got " .. tostring(item.areaName))
  end

  -- test_wow_item_without_guid_gets_who_zone
  do
    PresenceCache._reset()
    SeenZone._reset()
    SeenZone.Record("Someone-Realm", "Stormwind", 1000)
    local item = enrich({ channel = "WOW", displayName = "Someone-Realm" })
    assert(item.whoArea == "Stormwind", "got " .. tostring(item.whoArea))
    assert(item.whoAreaAt == 1000, "got " .. tostring(item.whoAreaAt))
    assert(item.areaName == nil, "areaName stays untouched, got " .. tostring(item.areaName))
  end

  -- test_live_zone_wins_over_who_zone
  do
    PresenceCache._reset()
    SeenZone._reset()
    SeenZone.Record("Someone", "Stormwind", 1000)
    PresenceCache._initForTest(
      makeMockClubApi({
        { guid = "Player-WoW-1", presence = 1, zone = "Dornogal" },
      }),
      {
        now = function()
          return 100
        end,
      }
    )
    local item = enrich({ channel = "WOW", displayName = "Someone", guid = "Player-WoW-1" })
    assert(item.areaName == "Dornogal", "live zone kept, got " .. tostring(item.areaName))
    assert(item.whoArea == nil, "got " .. tostring(item.whoArea))
    assert(item.whoAreaAt == nil, "got " .. tostring(item.whoAreaAt))
  end

  -- test_live_zone_clears_stale_who_zone_on_item
  do
    PresenceCache._reset()
    SeenZone._reset()
    SeenZone.Record("Someone", "Stormwind", 1000)
    PresenceCache._initForTest(
      makeMockClubApi({
        { guid = "Player-WoW-1", presence = 1, zone = "Dornogal" },
      }),
      {
        now = function()
          return 100
        end,
      }
    )
    local item = enrich({
      channel = "WOW",
      displayName = "Someone",
      guid = "Player-WoW-1",
      whoArea = "Old",
      whoAreaAt = 5,
    })
    assert(item.whoArea == nil, "live zone should clear a stale whoArea, got " .. tostring(item.whoArea))
    assert(item.whoAreaAt == nil, "live zone should clear a stale whoAreaAt, got " .. tostring(item.whoAreaAt))
  end

  -- test_who_zone_hidden_when_player_levels_setting_off
  do
    PresenceCache._reset()
    SeenZone._reset()
    SeenZone.Record("Someone", "Stormwind", 1000)
    DisplayName.Configure({ showPlayerLevels = false })
    local item = enrich({ channel = "WOW", displayName = "Someone", whoArea = "Old", whoAreaAt = 5 })
    DisplayName.Configure({ showPlayerLevels = true })
    assert(item.whoArea == nil, "setting off should clear whoArea, got " .. tostring(item.whoArea))
    assert(item.whoAreaAt == nil, "setting off should clear whoAreaAt, got " .. tostring(item.whoAreaAt))
  end

  -- test_bnet_item_gets_no_who_zone
  do
    PresenceCache._reset()
    SeenZone._reset()
    SeenZone.Record("Someone", "Stormwind", 1000)
    local item = enrich({ channel = "BN", displayName = "Someone" })
    assert(item.whoArea == nil, "got " .. tostring(item.whoArea))
    assert(item.areaName == nil, "got " .. tostring(item.areaName))
  end

  DisplayName.Configure({ showPlayerLevels = false })
  SeenZone._reset()
  PresenceCache._reset()
end
