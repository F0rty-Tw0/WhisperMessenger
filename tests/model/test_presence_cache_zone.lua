local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

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

return function()
  -- GetZone returns member zone after _initForTest
  do
    PresenceCache._reset()
    local api = makeMockClubApi({
      { guid = "Player-A", presence = 1, zone = "Dornogal" },
    })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetZone("Player-A") == "Dornogal", "should return member zone")
  end

  -- GetZone returns nil for unknown guid
  do
    PresenceCache._reset()
    local api = makeMockClubApi({
      { guid = "Player-A", presence = 1, zone = "Dornogal" },
    })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetZone("Player-unknown") == nil, "unknown guid should return nil")
  end

  -- GetZone returns nil for nil guid
  do
    PresenceCache._reset()
    local result = PresenceCache.GetZone(nil)
    assert(result == nil, "nil guid should return nil")
  end

  -- GetZone is nil when member info has no zone
  do
    PresenceCache._reset()
    local api = makeMockClubApi({
      { guid = "Player-B", presence = 1 },
    })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetZone("Player-B") == nil, "member with no zone should be nil")
  end

  -- RefreshPresence updates the zone when GetMemberInfo now returns a different zone
  do
    PresenceCache._reset()
    local currentZone = "Dornogal"
    -- guildMembers content is ignored below since GetMemberInfo is overridden;
    -- only the count (1) matters, for GetClubMembers to return one id.
    local api = makeMockClubApi({
      { guid = "Player-Refresh" },
    })
    api.GetMemberInfo = function(_clubId, _memberId)
      return { guid = "Player-Refresh", presence = 1, zone = currentZone }
    end
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetZone("Player-Refresh") == "Dornogal", "initial zone should be Dornogal")

    currentZone = "Voidscar Arena"
    PresenceCache.RefreshPresence("Player-Refresh")
    assert(PresenceCache.GetZone("Player-Refresh") == "Voidscar Arena", "RefreshPresence should update zone")
  end

  -- RefreshPresence must not raise when info.zone is a secret value (throws
  -- on read) and must leave the previously known zone in place.
  -- NOTE: a table's `~=` against a string never invokes __eq in Lua (only
  -- same-type comparisons do), so a throwing __eq cannot reach this path.
  -- A selective __index throw (same technique as
  -- test_presence_cache_targeted.lua) simulates the secret-value read.
  do
    PresenceCache._reset()
    local api = makeMockClubApi({
      { guid = "Player-Secret", presence = 1, zone = "Dornogal" },
    })
    PresenceCache._initForTest(api, {
      now = function()
        return 100
      end,
    })
    assert(PresenceCache.GetZone("Player-Secret") == "Dornogal", "precondition: zone starts as Dornogal")

    api.GetMemberInfo = function(_clubId, _memberId)
      return setmetatable({ guid = "Player-Secret", presence = 1 }, {
        __index = function(_, k)
          if k == "zone" then
            error("secret zone")
          end
          return nil
        end,
      })
    end

    local ok, result = pcall(PresenceCache.RefreshPresence, "Player-Secret")
    assert(ok, "RefreshPresence must not propagate a secret-zone read error: " .. tostring(result))
    assert(PresenceCache.GetZone("Player-Secret") == "Dornogal", "previous zone should remain after a secret-zone throw")
  end

  print("  All PresenceCache zone tests passed")
end
