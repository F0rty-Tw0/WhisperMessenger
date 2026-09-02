local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

-- Mock club API that counts every call, so tests can assert on API traffic
-- rather than on cache contents alone.
local function makeCountingClubApi(options)
  options = options or {}
  local guildMembers = options.guildMembers or {}
  local communities = options.communities or {}
  local guildClubId = options.guildClubId or 1
  local subscribedClubIds = options.subscribedClubIds

  local counts = { memberInfo = 0, clubMembers = 0, clubMembersById = {} }

  local function idsFor(list)
    local ids = {}
    for i = 1, #list do
      ids[i] = i
    end
    return ids
  end

  local api = {
    GetGuildClubId = function()
      return guildClubId
    end,
    GetSubscribedClubs = function()
      local clubs = {}
      if subscribedClubIds then
        for _, clubId in ipairs(subscribedClubIds) do
          table.insert(clubs, { clubId = clubId })
        end
        return clubs
      end
      for clubId in pairs(communities) do
        table.insert(clubs, { clubId = clubId })
      end
      return clubs
    end,
    GetClubMembers = function(clubId)
      counts.clubMembers = counts.clubMembers + 1
      counts.clubMembersById[clubId] = (counts.clubMembersById[clubId] or 0) + 1
      if clubId == guildClubId then
        return idsFor(guildMembers)
      end
      local members = communities[clubId]
      if members then
        return idsFor(members)
      end
      return {}
    end,
    GetMemberInfo = function(clubId, memberId)
      counts.memberInfo = counts.memberInfo + 1
      if clubId == guildClubId then
        return guildMembers[memberId]
      end
      local members = communities[clubId]
      if members then
        return members[memberId]
      end
      return nil
    end,
  }

  return api, counts
end

return function()
  -- RefreshPresence uses the index: exactly one member lookup for a known
  -- GUID, and it returns the live value.
  do
    PresenceCache._reset()
    local presence = 3
    local api, counts = makeCountingClubApi({
      guildMembers = {
        { guid = "Player-Other", presence = 1 },
        { guid = "Player-Indexed", presence = 1 },
      },
    })
    local origGetMemberInfo = api.GetMemberInfo
    api.GetMemberInfo = function(clubId, memberId)
      local info = origGetMemberInfo(clubId, memberId)
      if info and info.guid == "Player-Indexed" then
        return { guid = "Player-Indexed", presence = presence }
      end
      return info
    end

    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })

    counts.memberInfo = 0
    counts.clubMembers = 0
    presence = 1
    local result = PresenceCache.RefreshPresence("Player-Indexed")
    assert(result == "online", "RefreshPresence should return the live value, got " .. tostring(result))
    assert(counts.memberInfo == 1, "RefreshPresence should make exactly one member lookup, got " .. counts.memberInfo)
    assert(counts.clubMembers == 0, "RefreshPresence must not re-enumerate club members, got " .. counts.clubMembers)
  end

  -- EnsureFresh is free inside the TTL and refetches once the TTL elapses.
  do
    PresenceCache._reset()
    local clock = 100
    local api, counts = makeCountingClubApi({
      guildMembers = {
        { guid = "Player-TTL", presence = 1 },
      },
    })
    PresenceCache._initForTest(api, {
      ttl = 30,
      now = function()
        return clock
      end,
    })

    counts.memberInfo = 0
    assert(PresenceCache.EnsureFresh("Player-TTL") == "online", "EnsureFresh should return the cached presence")
    assert(counts.memberInfo == 0, "EnsureFresh inside the TTL must not call the API, got " .. counts.memberInfo)

    clock = 129
    PresenceCache.EnsureFresh("Player-TTL")
    assert(counts.memberInfo == 0, "EnsureFresh at 29s must still be free, got " .. counts.memberInfo)

    clock = 130
    PresenceCache.EnsureFresh("Player-TTL")
    assert(counts.memberInfo == 1, "EnsureFresh after the TTL should refetch once, got " .. counts.memberInfo)
  end

  -- An unknown GUID does not trigger a rescan while the index is considered
  -- current, and the miss is remembered for the TTL.
  do
    PresenceCache._reset()
    local clock = 100
    local api, counts = makeCountingClubApi({
      guildMembers = {
        { guid = "Player-Known", presence = 1 },
      },
    })
    PresenceCache._initForTest(api, {
      ttl = 30,
      now = function()
        return clock
      end,
    })

    counts.clubMembers = 0
    counts.memberInfo = 0
    assert(PresenceCache.EnsureFresh("Player-Absent") == nil, "unknown GUID should resolve to nil")
    assert(counts.clubMembers == 0, "unknown GUID must not rescan clubs, got " .. counts.clubMembers)
    assert(counts.memberInfo == 0, "unknown GUID must not fan out member lookups, got " .. counts.memberInfo)

    PresenceCache.EnsureFresh("Player-Absent")
    assert(counts.clubMembers == 0, "repeat lookups of an unknown GUID must stay free, got " .. counts.clubMembers)
  end

  -- Invalidate allows at most one full rescan per rescan interval.
  do
    PresenceCache._reset()
    local clock = 0
    local api, counts = makeCountingClubApi({
      guildMembers = {
        { guid = "Player-Known", presence = 1 },
      },
    })
    PresenceCache._initForTest(api, {
      ttl = 30,
      now = function()
        return clock
      end,
    })

    counts.clubMembers = 0
    PresenceCache.Invalidate()

    clock = 400
    PresenceCache.EnsureFresh("Player-Missing-1")
    assert(counts.clubMembers == 1, "first miss after invalidation should rescan once, got " .. counts.clubMembers)

    PresenceCache.EnsureFresh("Player-Missing-2")
    assert(counts.clubMembers == 1, "second miss in the same interval must not rescan, got " .. counts.clubMembers)

    PresenceCache.Invalidate()
    clock = 500
    PresenceCache.EnsureFresh("Player-Missing-3")
    assert(counts.clubMembers == 1, "a miss inside the rescan interval must not rescan, got " .. counts.clubMembers)

    clock = 750
    PresenceCache.EnsureFresh("Player-Missing-4")
    assert(counts.clubMembers == 2, "a miss after the rescan interval should rescan again, got " .. counts.clubMembers)
  end

  -- The guild club is scanned once even when it also appears in the
  -- subscribed-club list.
  do
    PresenceCache._reset()
    local api, counts = makeCountingClubApi({
      guildClubId = 7,
      guildMembers = {
        { guid = "Player-Guild", presence = 1 },
      },
      communities = {
        [10] = {
          { guid = "Player-Community", presence = 1 },
        },
      },
      subscribedClubIds = { 7, 10 },
    })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })

    assert(counts.clubMembersById[7] == 1, "guild club should be enumerated once, got " .. tostring(counts.clubMembersById[7]))
    assert(counts.clubMembersById[10] == 1, "community club should be enumerated once, got " .. tostring(counts.clubMembersById[10]))
    assert(PresenceCache.GetPresence("Player-Guild") == "online", "guild member should still be cached")
    assert(PresenceCache.GetPresence("Player-Community") == "online", "community member should still be cached")
  end

  -- EnsureFresh is inert without a GUID or a club API.
  do
    PresenceCache._reset()
    assert(PresenceCache.EnsureFresh(nil) == nil, "EnsureFresh(nil) should return nil")
    assert(PresenceCache.EnsureFresh("Player-Any") == nil, "EnsureFresh without a club API should return nil")
  end

  print("  All targeted PresenceCache tests passed")
end
