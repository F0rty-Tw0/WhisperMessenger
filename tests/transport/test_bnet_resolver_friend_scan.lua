local FriendScan = require("WhisperMessenger.Transport.BNetResolver.FriendScan")

local function identity(value)
  return value
end

local function buildApi(friends)
  local calls = { friendInfo = 0 }
  local api = {
    GetNumFriends = function()
      return #friends
    end,
    GetFriendAccountInfo = function(i)
      calls.friendInfo = calls.friendInfo + 1
      return friends[i] or nil
    end,
  }
  return api, calls
end

local FRIENDS = {
  { bnetAccountID = 11, battleTag = "Tag#11" },
  false,
  { bnetAccountID = 13, battleTag = "Tag#13" },
  { bnetAccountID = 14, battleTag = "Tag#14" },
}

return function()
  -- test_by_id_stops_at_the_matching_friend

  do
    local api, calls = buildApi(FRIENDS)
    local info, friendIndex = FriendScan.ById(api, 13, identity)
    assert(info == FRIENDS[3] and friendIndex == 3, "found past an empty entry, with its list position")
    assert(calls.friendInfo == 3, "the scan stops at the match, got " .. calls.friendInfo)
  end

  -- test_by_id_ignores_ids_the_sanitizer_rejects

  do
    local info, friendIndex = FriendScan.ById(buildApi(FRIENDS), 13, function(_value)
      return nil
    end)
    assert(info == nil and friendIndex == nil, "an unreadable ID is not a match")
  end

  -- test_by_battle_tag_reports_a_readable_list

  do
    local info, friendIndex, listAvailable = FriendScan.ByBattleTag(buildApi(FRIENDS), "Tag#14")
    assert(info == FRIENDS[4] and friendIndex == 4 and listAvailable == true, "found by battle tag")
    local missing, _, stillAvailable = FriendScan.ByBattleTag(buildApi(FRIENDS), "Tag#99")
    assert(missing == nil and stillAvailable == true, "not listed, but the list was read")
  end

  -- test_missing_friend_list_api_finds_nothing

  do
    local savedGlobal = _G.BNGetNumFriends
    _G.BNGetNumFriends = nil
    local byId = FriendScan.ById({}, 13, identity)
    local byTag, _, listAvailable = FriendScan.ByBattleTag({}, "Tag#13")
    _G.BNGetNumFriends = savedGlobal
    assert(byId == nil and byTag == nil, "no friend list, no match")
    assert(listAvailable == false, "the battle tag scan says the list was unreadable")
  end
end
