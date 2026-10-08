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

local function initWith(members)
  PresenceCache._reset()
  local api = makeMockClubApi(members)
  PresenceCache._initForTest(api, {
    now = function()
      return 100
    end,
  })
  return api
end

-- Init with a movable clock, then count club API calls made after the scan.
local function initCounted(members)
  PresenceCache._reset()
  local api = makeMockClubApi(members)
  local clock = { now = 100 }
  PresenceCache._initForTest(api, {
    now = function()
      return clock.now
    end,
  })
  local calls = { members = 0, info = 0 }
  local getClubMembers = api.GetClubMembers
  local getMemberInfo = api.GetMemberInfo
  api.GetClubMembers = function(...)
    calls.members = calls.members + 1
    return getClubMembers(...)
  end
  api.GetMemberInfo = function(...)
    calls.info = calls.info + 1
    return getMemberInfo(...)
  end
  return api, calls, clock
end

-- Member info whose `key` field throws on read, simulating a 12.0 secret value.
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
  -- full scan records the member's level
  do
    initWith({ { guid = "Player-A", presence = 1, level = 80 } })
    assert(PresenceCache.GetLevel("Player-A") == 80, "should return member level")
  end

  -- non-positive and non-number levels are ignored
  do
    initWith({
      { guid = "Player-Zero", presence = 1, level = 0 },
      { guid = "Player-Text", presence = 1, level = "80" },
    })
    assert(PresenceCache.GetLevel("Player-Zero") == nil, "level 0 should be ignored")
    assert(PresenceCache.GetLevel("Player-Text") == nil, "string level should be ignored")
  end

  -- GetLevel returns nil for unknown and nil guids
  do
    initWith({})
    assert(PresenceCache.GetLevel("Player-Nobody") == nil, "unknown guid should have no level")
    assert(PresenceCache.GetLevel(nil) == nil, "nil guid should have no level")
  end

  -- RefreshPresence picks up a level-up
  do
    local member = { guid = "Player-Ding", presence = 1, level = 79 }
    initWith({ member })
    member.level = 80
    PresenceCache.RefreshPresence("Player-Ding")
    assert(PresenceCache.GetLevel("Player-Ding") == 80, "RefreshPresence should update level")
  end

  -- a secret level on the full scan still records presence and zone
  do
    initWith({ secretField({ guid = "Player-SecretLevel", presence = 1, zone = "Dornogal" }, "level") })
    assert(PresenceCache.GetPresence("Player-SecretLevel") == "online", "presence should survive a secret level")
    assert(PresenceCache.GetZone("Player-SecretLevel") == "Dornogal", "zone should survive a secret level")
    assert(PresenceCache.GetLevel("Player-SecretLevel") == nil, "secret level should not be recorded")
  end

  -- a secret presence on the targeted refresh still updates the level
  do
    local api = initWith({ { guid = "Player-SecretPresence", presence = 1, level = 80 } })
    api.GetMemberInfo = function(_clubId, _memberId)
      return secretField({ guid = "Player-SecretPresence", level = 81 }, "presence")
    end
    local ok, err = pcall(PresenceCache.RefreshPresence, "Player-SecretPresence")
    assert(ok, "RefreshPresence must not raise on a secret presence: " .. tostring(err))
    assert(PresenceCache.GetLevel("Player-SecretPresence") == 81, "level should update despite a secret presence")
  end

  -- ReadLevel reads an indexed member live without rescanning the club
  do
    local member = { guid = "Player-A", presence = 1, level = 80 }
    local _api, calls = initCounted({ member })
    member.level = 81
    assert(PresenceCache.ReadLevel("Player-A") == 81, "ReadLevel should return the live level")
    assert(calls.members == 0, "ReadLevel must not rebuild the index")
  end

  -- ReadLevel on an unknown GUID makes no API call, even when the index is stale
  do
    local _api, calls, clock = initCounted({ { guid = "Player-A", presence = 1, level = 80 } })
    PresenceCache.Invalidate()
    clock.now = 400
    assert(PresenceCache.ReadLevel("Player-Stranger") == nil, "unknown guid should have no level")
    assert(calls.info == 0, "unknown guid must not call GetMemberInfo")
    assert(calls.members == 0, "unknown guid must not rebuild the index")
  end

  -- ReadLevel keeps the last known level when the live read throws
  do
    local api = initWith({ { guid = "Player-A", presence = 1, level = 80 } })
    api.GetMemberInfo = function()
      error("club api failed")
    end
    local ok, level = pcall(PresenceCache.ReadLevel, "Player-A")
    assert(ok, "ReadLevel must not raise: " .. tostring(level))
    assert(level == 80, "ReadLevel should fall back to the last known level")
  end

  -- ReadLevel leaves presence untouched
  do
    local member = { guid = "Player-A", presence = 1, level = 80 }
    initWith({ member })
    local before = PresenceCache.GetPresence("Player-A")
    member.presence = 2
    PresenceCache.ReadLevel("Player-A")
    assert(PresenceCache.GetPresence("Player-A") == before, "ReadLevel must not change presence")
  end

  -- ReadLevel returns nil for a nil guid
  do
    initWith({})
    assert(PresenceCache.ReadLevel(nil) == nil, "nil guid should have no level")
  end

  -- _reset clears levels
  do
    initWith({ { guid = "Player-A", presence = 1, level = 80 } })
    PresenceCache._reset()
    assert(PresenceCache.GetLevel("Player-A") == nil, "_reset should clear levels")
  end

  print("  All PresenceCache level tests passed")
end
