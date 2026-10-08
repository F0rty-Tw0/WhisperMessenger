local PresenceCache = require("WhisperMessenger.Model.PresenceCache")
local SenderLevel = require("WhisperMessenger.Model.SenderLevel")

local GUID = "Player-1-0001"
local STUBBED = { "UnitTokenFromGUID", "UnitLevel", "UnitGUID", "IsInRaid", "GetNumGroupMembers", "C_BattleNet" }

local function seedGuild(members)
  PresenceCache._reset()
  PresenceCache._initForTest({
    GetGuildClubId = function()
      return 1
    end,
    GetSubscribedClubs = function()
      return {}
    end,
    GetClubMembers = function()
      local ids = {}
      for i = 1, #members do
        ids[i] = i
      end
      return ids
    end,
    GetMemberInfo = function(_clubId, memberId)
      return members[memberId]
    end,
  }, {
    now = function()
      return 100
    end,
  })
end

-- Value whose `key` field throws on read, simulating a 12.0 secret value.
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

local function withToken(token)
  rawset(_G, "UnitTokenFromGUID", function(guid)
    if guid == GUID then
      return token
    end
    return nil
  end)
end

local function withUnitLevels(levels)
  rawset(_G, "UnitLevel", function(unit)
    return levels[unit]
  end)
end

local function withBNet(gameAccountInfo)
  _G.C_BattleNet = {
    GetAccountInfoByGUID = function(guid)
      if guid == GUID then
        return { gameAccountInfo = gameAccountInfo }
      end
      return nil
    end,
  }
end

local function lookupSafely(guid)
  local ok, level = pcall(SenderLevel.Lookup, guid)
  assert(ok, "Lookup must not raise: " .. tostring(level))
  return level
end

return function()
  local saved = {}
  for _, name in ipairs(STUBBED) do
    saved[name] = _G[name]
  end
  local function reset()
    for _, name in ipairs(STUBBED) do
      _G[name] = nil
    end
    PresenceCache._reset()
  end

  -- party member resolved through UnitTokenFromGUID
  do
    reset()
    withToken("party2")
    withUnitLevels({ party2 = 20 })
    assert(lookupSafely(GUID) == 20, "party member level should be 20")
  end

  -- a non-group token (nameplate) is not a level source
  do
    reset()
    withToken("nameplate3")
    withUnitLevels({ nameplate3 = 20 })
    assert(lookupSafely(GUID) == nil, "nameplate token must not leak a level")
  end

  -- without UnitTokenFromGUID the party roster is scanned by GUID
  do
    reset()
    rawset(_G, "IsInRaid", function()
      return false
    end)
    rawset(_G, "GetNumGroupMembers", function()
      return 3
    end)
    rawset(_G, "UnitGUID", function(unit)
      if unit == "party1" then
        return GUID
      end
      return nil
    end)
    withUnitLevels({ party1 = 22 })
    assert(lookupSafely(GUID) == 22, "scanned party member level should be 22")
  end

  -- the party scan reaches the last party slot (party1..count-1)
  do
    reset()
    rawset(_G, "IsInRaid", function()
      return false
    end)
    rawset(_G, "GetNumGroupMembers", function()
      return 3
    end)
    rawset(_G, "UnitGUID", function(unit)
      if unit == "party2" then
        return GUID
      end
      return nil
    end)
    withUnitLevels({ party2 = 23 })
    assert(lookupSafely(GUID) == 23, "last party slot level should be 23")
  end

  -- in a raid the scan walks raid1..count, including the last slot
  do
    reset()
    rawset(_G, "IsInRaid", function()
      return true
    end)
    rawset(_G, "GetNumGroupMembers", function()
      return 25
    end)
    rawset(_G, "UnitGUID", function(unit)
      if unit == "raid25" then
        return GUID
      end
      return nil
    end)
    withUnitLevels({ raid25 = 24 })
    assert(lookupSafely(GUID) == 24, "last raid slot level should be 24")
  end

  -- guild cache level when not grouped
  do
    reset()
    seedGuild({ { guid = GUID, presence = 1, level = 70 } })
    assert(lookupSafely(GUID) == 70, "guild member level should be 70")
  end

  -- Battle.net friend level when the game account matches the GUID
  do
    reset()
    withBNet({ playerGuid = GUID, characterLevel = 60 })
    assert(lookupSafely(GUID) == 60, "bnet friend level should be 60")
  end

  -- Battle.net game account on another character is ignored
  do
    reset()
    withBNet({ playerGuid = "Player-other", characterLevel = 60 })
    assert(lookupSafely(GUID) == nil, "other character's level must be ignored")
  end

  -- group level wins over the guild cache
  do
    reset()
    seedGuild({ { guid = GUID, presence = 1, level = 70 } })
    withToken("raid5")
    withUnitLevels({ raid5 = 20 })
    assert(lookupSafely(GUID) == 20, "group level should win over guild cache")
  end

  -- nil guid and no source give nil
  do
    reset()
    assert(lookupSafely(nil) == nil, "nil guid should have no level")
    assert(lookupSafely(GUID) == nil, "no source should give no level")
  end

  -- level 0 from the unit falls through to the next source
  do
    reset()
    seedGuild({ { guid = GUID, presence = 1, level = 70 } })
    withToken("party1")
    withUnitLevels({ party1 = 0 })
    assert(lookupSafely(GUID) == 70, "level 0 should fall through to guild cache")
  end

  -- a throwing UnitLevel falls through to the next source
  do
    reset()
    seedGuild({ { guid = GUID, presence = 1, level = 70 } })
    withToken("party1")
    rawset(_G, "UnitLevel", function()
      error("UnitLevel failed")
    end)
    assert(lookupSafely(GUID) == 70, "throwing UnitLevel should fall through")
  end

  -- a throwing UnitTokenFromGUID does not raise
  do
    reset()
    rawset(_G, "UnitTokenFromGUID", function()
      error("UnitTokenFromGUID failed")
    end)
    assert(lookupSafely(GUID) == nil, "throwing token lookup should give nil")
  end

  -- secret characterLevel on the Battle.net game account
  do
    reset()
    withBNet(secretField({ playerGuid = GUID }, "characterLevel"))
    assert(lookupSafely(GUID) == nil, "secret characterLevel should give nil")
  end

  -- secret playerGuid on the Battle.net game account
  do
    reset()
    withBNet(secretField({ characterLevel = 60 }, "playerGuid"))
    assert(lookupSafely(GUID) == nil, "secret playerGuid should give nil")
  end

  for _, name in ipairs(STUBBED) do
    _G[name] = saved[name]
  end
  PresenceCache._reset()

  print("  All SenderLevel tests passed")
end
