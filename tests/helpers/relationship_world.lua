local PresenceCache = require("WhisperMessenger.Model.PresenceCache")

local World = {}

local GLOBALS = { "C_GuildInfo", "C_FriendList", "C_Club", "GetGuildInfo", "GetPlayerInfoByGUID", "issecretvalue" }

-- World.New() resets the stubbed globals and PresenceCache and returns w:
--   w.runtime            { now, bnetApi, accountState = { settings = {} } }
--   w.calls              counters: guild, guildInfo, isFriend, friendInfo, bnetGuid, clubInfo, account
--   w.nilArgs            number of tie-API calls that received a nil argument
--   w.playerInfoCalls    GetPlayerInfoByGUID calls
--   w.playerInfo[guid] = { name, realm }   what GetPlayerInfoByGUID answers (nothing by default, so names stay as given)
--   w.guildMembers[name] / w.friendGuids[guid] / w.friendNames[name] / w.bnetByGuid[guid] = table / w.clubNames[id]
--   w.guildName          what GetGuildInfo("player") returns (nil = not in a guild)
--   w.guildThrows / w.guildSecret   make MemberExistsByName throw / return "SECRET"
--   w.friendThrows       make GetFriendInfo throw
--   w.lastGuildName / w.lastFriendName   last name argument seen
--   w.now                clock used by runtime.now
--   w.setCommunity(guid, clubId, clubName)   index the guid under a community club (guild club 1 stays empty)
--   w.setBNet(accountID, gameInfo)           GetAccountInfoByID answers a WoW-online account with this gameInfo
--   w.item(guid, name) -> WOW item;  w.bnItem(accountID) -> BN item
--   w.totalCalls() -> sum of w.calls
function World.New()
  local w = {
    calls = { guild = 0, guildInfo = 0, isFriend = 0, friendInfo = 0, bnetGuid = 0, clubInfo = 0, account = 0 },
    nilArgs = 0,
    playerInfoCalls = 0,
    guildMembers = {},
    friendGuids = {},
    friendNames = {},
    bnetByGuid = {},
    clubNames = {},
    accounts = {},
    communities = {},
    playerInfo = {},
    guildName = "Moonwatch",
    now = 1000,
  }
  local function hit(name, arg)
    w.calls[name] = w.calls[name] + 1
    if arg == nil then
      w.nilArgs = w.nilArgs + 1
    end
  end
  for _, name in ipairs(GLOBALS) do
    rawset(_G, name, nil)
  end
  rawset(_G, "C_GuildInfo", {
    MemberExistsByName = function(name)
      hit("guild", name)
      w.lastGuildName = name
      if w.guildThrows then
        error("guild api failed")
      end
      if w.guildSecret then
        return "SECRET"
      end
      return w.guildMembers[name] == true
    end,
  })
  -- Counted apart from w.calls: it is the name lookup, not a tie API.
  rawset(_G, "GetPlayerInfoByGUID", function(guid)
    w.playerInfoCalls = w.playerInfoCalls + 1
    local info = w.playerInfo[guid]
    if info == nil then
      return nil
    end
    return nil, nil, nil, nil, nil, info.name, info.realm
  end)
  rawset(_G, "GetGuildInfo", function(unit)
    hit("guildInfo", unit)
    return w.guildName
  end)
  rawset(_G, "C_FriendList", {
    IsFriend = function(guid)
      hit("isFriend", guid)
      return w.friendGuids[guid] == true
    end,
    GetFriendInfo = function(name)
      hit("friendInfo", name)
      w.lastFriendName = name
      if w.friendThrows then
        error("friend api failed")
      end
      if w.friendNames[name] then
        return { connected = true }
      end
      return nil
    end,
  })
  rawset(_G, "C_Club", {
    GetClubInfo = function(clubId)
      hit("clubInfo", clubId)
      return { name = w.clubNames[clubId] }
    end,
  })
  local bnetApi = {
    GetAccountInfoByGUID = function(guid)
      hit("bnetGuid", guid)
      return w.bnetByGuid[guid]
    end,
    GetAccountInfoByID = function(accountID)
      w.calls.account = w.calls.account + 1
      return w.accounts[accountID]
    end,
  }
  w.runtime = {
    now = function()
      return w.now
    end,
    bnetApi = bnetApi,
    accountState = { settings = {} },
  }
  PresenceCache._reset()

  function w.setCommunity(guid, clubId, clubName)
    w.communities[#w.communities + 1] = { guid = guid, id = clubId }
    w.clubNames[clubId] = clubName
    local clubs, members = {}, { [1] = {} }
    for _, c in ipairs(w.communities) do
      clubs[#clubs + 1] = { clubId = c.id }
      members[c.id] = members[c.id] or {}
      members[c.id][#members[c.id] + 1] = { guid = c.guid, presence = 1 }
    end
    PresenceCache._reset()
    PresenceCache._initForTest({
      GetGuildClubId = function()
        return 1
      end,
      GetSubscribedClubs = function()
        return clubs
      end,
      GetClubMembers = function(id)
        local ids = {}
        for i = 1, #(members[id] or {}) do
          ids[i] = i
        end
        return ids
      end,
      GetMemberInfo = function(id, memberId)
        return members[id][memberId]
      end,
    }, {
      now = function()
        return 100
      end,
    })
  end

  function w.setBNet(accountID, gameInfo)
    w.accounts[accountID] = { bnetAccountID = accountID, battleTag = "Frodo#1", isOnline = true, gameAccountInfo = gameInfo }
  end

  function w.item(guid, name)
    return { conversationKey = "me::WOW::" .. tostring(name), channel = "WOW", guid = guid, displayName = name }
  end

  function w.bnItem(accountID)
    return { conversationKey = "me::BN::" .. accountID, channel = "BN", bnetAccountID = accountID, battleTag = "Frodo#1", displayName = "Frodo#1" }
  end

  function w.totalCalls()
    local sum = 0
    for _, n in pairs(w.calls) do
      sum = sum + n
    end
    return sum
  end

  return w
end

return World
