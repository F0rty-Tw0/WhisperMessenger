local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

local GUILD, COMM_A, COMM_B = 1, 2, 3

-- membersByClub[clubId] = { info, ... }; subscribed lists club ids in API order
-- (the real API lists the guild club here too).
local function makeApi(guildId, subscribed, membersByClub)
  return {
    GetGuildClubId = function()
      return guildId
    end,
    GetSubscribedClubs = function()
      local list = {}
      for _, id in ipairs(subscribed) do
        list[#list + 1] = { clubId = id }
      end
      return list
    end,
    GetClubMembers = function(clubId)
      local ids = {}
      for i = 1, #(membersByClub[clubId] or {}) do
        ids[i] = i
      end
      return ids
    end,
    GetMemberInfo = function(clubId, memberId)
      return membersByClub[clubId][memberId]
    end,
  }
end

local function build(guildId, subscribed, membersByClub, clock)
  PresenceCache._reset()
  local api = makeApi(guildId, subscribed, membersByClub)
  PresenceCache._initForTest(api, {
    now = function()
      return clock and clock.now or 100
    end,
  })
  return api
end

local function secretField(fields, key)
  return setmetatable(fields, {
    __index = function(_, k)
      if k == key then
        error("secret " .. key)
      end
      return nil
    end,
  })
end

return function()
  -- guildmate who is also in a community: index answers the community, never the guild club
  do
    build(GUILD, { GUILD, COMM_A }, {
      [GUILD] = { { guid = "Player-Both", presence = 1 }, { guid = "Player-GuildOnly", presence = 1 } },
      [COMM_A] = { { guid = "Player-Both", presence = 1 } },
    })
    assert(PresenceCache.GetCommunityClubId("Player-Both") == COMM_A, "guildmate in a community should map to the community")
    assert(PresenceCache.GetCommunityClubId("Player-GuildOnly") == nil, "guild-only member has no community")
  end

  -- GetGuildClubId failed: the guild club is still known by its club type
  do
    local savedEnum = rawget(_G, "Enum")
    rawset(_G, "Enum", { ClubType = { Character = 1, Guild = 2 } })
    local api = makeApi(nil, {}, {
      [GUILD] = { { guid = "Player-Both", presence = 1 }, { guid = "Player-GuildOnly", presence = 1 } },
      [COMM_A] = { { guid = "Player-Both", presence = 1 } },
    })
    api.GetGuildClubId = function()
      error("guild club not ready")
    end
    api.GetSubscribedClubs = function()
      return { { clubId = GUILD, clubType = 2 }, { clubId = COMM_A, clubType = 1 } }
    end
    PresenceCache._reset()
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetCommunityClubId("Player-GuildOnly") == nil, "a guildmate must not be indexed under the guild club")
    assert(PresenceCache.GetCommunityClubId("Player-Both") == COMM_A, "a guildmate in a community still maps to the community")
    assert(PresenceCache.GetPresence("Player-GuildOnly") == "online", "guild members still get presence")
    rawset(_G, "Enum", savedEnum)
  end

  -- member of two communities: the first one in API order wins
  do
    build(GUILD, { GUILD, COMM_A, COMM_B }, {
      [GUILD] = {},
      [COMM_A] = { { guid = "Player-Two", presence = 1 } },
      [COMM_B] = { { guid = "Player-Two", presence = 1 } },
    })
    assert(PresenceCache.GetCommunityClubId("Player-Two") == COMM_A, "first community wins")
  end

  -- no guild at all: every club is a community
  do
    build(nil, { COMM_A }, { [COMM_A] = { { guid = "Player-NoGuild", presence = 1 } } })
    assert(PresenceCache.GetCommunityClubId("Player-NoGuild") == COMM_A, "community recorded with no guild")
  end

  -- a secret zone or level still records the community
  do
    build(GUILD, { GUILD, COMM_A }, {
      [GUILD] = {},
      [COMM_A] = {
        secretField({ guid = "Player-SecretZone", presence = 1 }, "zone"),
        secretField({ guid = "Player-SecretLevel", presence = 1, zone = "Dornogal" }, "level"),
      },
    })
    assert(PresenceCache.GetCommunityClubId("Player-SecretZone") == COMM_A, "secret zone must not drop the community")
    assert(PresenceCache.GetCommunityClubId("Player-SecretLevel") == COMM_A, "secret level must not drop the community")
  end

  -- a lookup never rescans, even when the index is stale
  do
    local clock = { now = 100 }
    local api = build(GUILD, { GUILD, COMM_A }, { [GUILD] = {}, [COMM_A] = { { guid = "Player-A", presence = 1 } } }, clock)
    local scans = 0
    local inner = api.GetClubMembers
    api.GetClubMembers = function(...)
      scans = scans + 1
      return inner(...)
    end
    PresenceCache.Invalidate()
    clock.now = 1000
    assert(PresenceCache.GetCommunityClubId("Player-Stranger") == nil, "unknown guid has no community")
    assert(PresenceCache.GetCommunityClubId(nil) == nil, "nil guid has no community")
    assert(scans == 0, "GetCommunityClubId must not rescan")
  end

  -- a rebuild swaps the map: a member who left the community disappears
  do
    local members = { [GUILD] = {}, [COMM_A] = { { guid = "Player-Leaver", presence = 1 } } }
    build(GUILD, { GUILD, COMM_A }, members)
    assert(PresenceCache.GetCommunityClubId("Player-Leaver") == COMM_A, "precondition")
    members[COMM_A] = {}
    PresenceCache.Rebuild()
    assert(PresenceCache.GetCommunityClubId("Player-Leaver") == nil, "Rebuild should drop the departed member")
  end

  -- _reset empties the map
  do
    build(GUILD, { GUILD, COMM_A }, { [GUILD] = {}, [COMM_A] = { { guid = "Player-A", presence = 1 } } })
    PresenceCache._reset()
    assert(PresenceCache.GetCommunityClubId("Player-A") == nil, "_reset should clear the community map")
  end

  -- IndexGeneration goes up on every Rebuild, and never repeats after _reset
  do
    build(GUILD, { GUILD }, { [GUILD] = {} })
    local first = PresenceCache.IndexGeneration()
    PresenceCache.Rebuild()
    local second = PresenceCache.IndexGeneration()
    assert(second > first, "Rebuild should bump the generation")
    PresenceCache._reset()
    PresenceCache._initForTest(makeApi(GUILD, { GUILD }, { [GUILD] = {} }))
    assert(PresenceCache.IndexGeneration() > second, "generation must not go back after _reset")
  end

  print("  All PresenceCache community tests passed")
end
