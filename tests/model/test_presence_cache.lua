local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

local function makeMockClubApi(options)
  options = options or {}
  local guildMembers = options.guildMembers or {}
  local communities = options.communities or {}
  local guildClubId = options.guildClubId or 1

  return {
    GetGuildClubId = function()
      return guildClubId
    end,
    GetSubscribedClubs = function()
      local clubs = {}
      for clubId, _ in pairs(communities) do
        table.insert(clubs, { clubId = clubId })
      end
      return clubs
    end,
    GetClubMembers = function(clubId)
      if clubId == guildClubId then
        local ids = {}
        for i = 1, #guildMembers do
          ids[i] = i
        end
        return ids
      end
      local communityMembers = communities[clubId]
      if communityMembers then
        local ids = {}
        for i = 1, #communityMembers do
          ids[i] = i
        end
        return ids
      end
      return {}
    end,
    GetMemberInfo = function(clubId, memberId)
      if clubId == guildClubId then
        return guildMembers[memberId]
      end
      local communityMembers = communities[clubId]
      if communityMembers then
        return communityMembers[memberId]
      end
      return nil
    end,
  }
end

return function()
  -- GetPresence returns nil for nil guid
  do
    PresenceCache._reset()
    local result = PresenceCache.GetPresence(nil)
    assert(result == nil, "nil guid should return nil")
  end

  -- GetPresence returns nil for unknown guid
  do
    PresenceCache._reset()
    PresenceCache._setCache({ ["Player-1"] = "online" })
    local result = PresenceCache.GetPresence("Player-unknown")
    assert(result == nil, "unknown guid should return nil")
  end

  -- GetPresence returns cached presence via O(1) lookup
  do
    PresenceCache._reset()
    PresenceCache._setCache({
      ["Player-1"] = "online",
      ["Player-2"] = "offline",
    })
    assert(PresenceCache.GetPresence("Player-1") == "online", "should return online")
    assert(PresenceCache.GetPresence("Player-2") == "offline", "should return offline")
  end

  -- Rebuild scans guild members and populates cache
  do
    PresenceCache._reset()
    local api = makeMockClubApi({
      guildMembers = {
        { guid = "Player-A", presence = 1 }, -- Online
        { guid = "Player-B", presence = 3 }, -- Offline
        { guid = "Player-C", presence = 2 }, -- OnlineMobile
      },
    })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetPresence("Player-A") == "online", "Online presence should map to online")
    assert(PresenceCache.GetPresence("Player-B") == "offline", "Offline presence should map to offline")
    assert(PresenceCache.GetPresence("Player-C") == "online", "OnlineMobile presence should map to online")
  end

  -- Rebuild scans community members too
  do
    PresenceCache._reset()
    local api = makeMockClubApi({
      guildMembers = {
        { guid = "Player-Guild", presence = 1 },
      },
      communities = {
        [10] = {
          { guid = "Player-Community", presence = 1 },
        },
      },
    })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetPresence("Player-Guild") == "online", "guild member should be cached")
    assert(PresenceCache.GetPresence("Player-Community") == "online", "community member should be cached")
  end

  -- Rebuild replaces entire cache (stale entries removed)
  do
    PresenceCache._reset()
    local api = makeMockClubApi({
      guildMembers = {
        { guid = "Player-A", presence = 1 },
      },
    })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetPresence("Player-A") == "online", "initial: Player-A should be online")

    -- Simulate Player-A leaving guild (no longer in members list)
    local api2 = makeMockClubApi({ guildMembers = {} })
    PresenceCache._initForTest(api2, {
      now = function()
        return 200
      end,
    })
    assert(PresenceCache.GetPresence("Player-A") == nil, "after rebuild: Player-A should be gone")
  end

  -- Presence enum 4 (Away) maps to online
  do
    PresenceCache._reset()
    local api = makeMockClubApi({
      guildMembers = {
        { guid = "Player-Away", presence = 4 },
      },
    })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetPresence("Player-Away") == "online", "Away (4) should map to online")
  end

  -- Presence enum 0 (Unknown) maps to nil (not cached)
  do
    PresenceCache._reset()
    local api = makeMockClubApi({
      guildMembers = {
        { guid = "Player-Unknown", presence = 0 },
      },
    })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetPresence("Player-Unknown") == nil, "Unknown (0) should not be cached")
  end

  -- Invalidate marks cache as stale
  do
    PresenceCache._reset()
    local api = makeMockClubApi({ guildMembers = {} })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.IsStale() == false, "fresh cache should not be stale")
    PresenceCache.Invalidate()
    assert(PresenceCache.IsStale() == true, "invalidated cache should be stale")
  end

  -- IsStale returns true when TTL expires
  do
    PresenceCache._reset()
    local clock = 100
    local api = makeMockClubApi({ guildMembers = {} })
    PresenceCache._initForTest(api, {
      ttl = 30,
      now = function()
        return clock
      end,
    })
    assert(PresenceCache.IsStale() == false, "just built: should not be stale")
    clock = 129
    assert(PresenceCache.IsStale() == false, "29s later: should not be stale yet")
    clock = 130
    assert(PresenceCache.IsStale() == true, "30s later: should be stale")
  end

  -- SetTTL updates the TTL
  do
    PresenceCache._reset()
    local clock = 100
    local api = makeMockClubApi({ guildMembers = {} })
    PresenceCache._initForTest(api, {
      ttl = 30,
      now = function()
        return clock
      end,
    })
    clock = 120
    assert(PresenceCache.IsStale() == false, "20s with 30s TTL: not stale")
    PresenceCache.SetTTL(15)
    assert(PresenceCache.IsStale() == true, "20s with 15s TTL: now stale")
  end

  -- _setCache sets cache directly for tests
  do
    PresenceCache._reset()
    PresenceCache._setCache({ ["test-guid"] = "online" })
    assert(PresenceCache.GetPresence("test-guid") == "online", "_setCache should set cache directly")
  end

  -- Rebuild handles nil clubApi gracefully
  do
    PresenceCache._reset()
    PresenceCache._initForTest(nil, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetPresence("any-guid") == nil, "nil clubApi: should return nil for any guid")
    assert(PresenceCache.IsStale() == false, "nil clubApi: should still mark as fresh after rebuild")
  end

  -- Rebuild handles pcall errors gracefully
  do
    PresenceCache._reset()
    local api = {
      GetGuildClubId = function()
        error("API unavailable")
      end,
      GetSubscribedClubs = function()
        error("API unavailable")
      end,
    }
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetPresence("any-guid") == nil, "erroring API: should return nil")
    assert(PresenceCache.IsStale() == false, "erroring API: should still mark as fresh")
  end

  -- Rebuild handles GetMemberInfo errors for individual members
  do
    PresenceCache._reset()
    local callCount = 0
    local api = makeMockClubApi({
      guildMembers = {
        { guid = "Player-OK", presence = 1 },
      },
    })
    -- Override GetMemberInfo to fail on second call
    local origGetMemberInfo = api.GetMemberInfo
    api.GetMemberInfo = function(clubId, memberId)
      callCount = callCount + 1
      if callCount == 1 then
        return origGetMemberInfo(clubId, memberId)
      end
      error("member info failed")
    end
    -- Add a second member that will fail
    api.GetClubMembers = function(_clubId)
      return { 1, 2 }
    end
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetPresence("Player-OK") == "online", "first member should still be cached")
  end

  -- RefreshPresence returns fresh presence for a single GUID
  do
    PresenceCache._reset()
    local currentPresence = 3 -- starts offline
    local api = makeMockClubApi({
      guildMembers = {
        { guid = "Player-Refresh", presence = currentPresence },
      },
    })
    -- Override GetMemberInfo to use dynamic presence
    api.GetMemberInfo = function(_clubId, _memberId)
      return { guid = "Player-Refresh", presence = currentPresence }
    end
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetPresence("Player-Refresh") == "offline", "initial: should be offline")

    -- Player comes online
    currentPresence = 1
    local result = PresenceCache.RefreshPresence("Player-Refresh")
    assert(result == "online", "RefreshPresence should return fresh online status")
    assert(PresenceCache.GetPresence("Player-Refresh") == "online", "cache should be updated to online")
  end

  -- RefreshPresence returns nil for GUID not in any club
  do
    PresenceCache._reset()
    local api = makeMockClubApi({ guildMembers = {} })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    local result = PresenceCache.RefreshPresence("Player-Unknown")
    assert(result == nil, "RefreshPresence for unknown GUID should return nil")
  end

  -- RefreshPresence returns nil for nil GUID
  do
    PresenceCache._reset()
    local result = PresenceCache.RefreshPresence(nil)
    assert(result == nil, "RefreshPresence for nil GUID should return nil")
  end

  -- RefreshPresence removes stale entry when GUID leaves guild
  do
    PresenceCache._reset()
    PresenceCache._setCache({ ["Player-Left"] = "online" })
    local api = makeMockClubApi({ guildMembers = {} })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    -- Manually set cache to have the old entry
    PresenceCache._setCache({ ["Player-Left"] = "online" })
    local result = PresenceCache.RefreshPresence("Player-Left")
    assert(result == nil, "RefreshPresence should return nil for player who left")
    assert(PresenceCache.GetPresence("Player-Left") == nil, "stale entry should be removed from cache")
  end

  -- RefreshPresence finds GUID in community when not in guild
  do
    PresenceCache._reset()
    local api = makeMockClubApi({
      guildMembers = {},
      communities = {
        [10] = {
          { guid = "Player-Community", presence = 1 },
        },
      },
    })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    -- Clear cache to simulate stale
    PresenceCache._setCache({})
    local result = PresenceCache.RefreshPresence("Player-Community")
    assert(result == "online", "RefreshPresence should find GUID in community")
    assert(PresenceCache.GetPresence("Player-Community") == "online", "cache should be updated")
  end

  print("  All PresenceCache tests passed")
end
