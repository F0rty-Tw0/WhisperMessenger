local FriendCandidates = require("WhisperMessenger.Transport.FriendCandidates")

local function friendList(friends)
  return {
    GetNumFriends = function()
      return #friends
    end,
    GetFriendInfoByIndex = function(index)
      return friends[index]
    end,
  }
end

local function battleNet(accounts)
  return {
    GetFriendAccountInfo = function(index)
      return accounts[index]
    end,
  }, function()
    return #accounts, #accounts
  end
end

return function()
  -- test_character_friends_online_first_then_by_name
  do
    local candidates = FriendCandidates.Collect({
      friendList = friendList({
        { name = "Zed", connected = true },
        { name = "Lone Gazer", connected = false },
        { name = "Anna", connected = true },
      }),
      localRealm = "Kazzak",
    })
    assert(#candidates == 3)
    assert(candidates[1].name == "Anna" and candidates[2].name == "Zed", "online friends first, by name")
    assert(candidates[3].name == "Lone Gazer" and candidates[3].online == false, "offline friends last")
  end

  -- test_battle_net_friends_in_this_game_are_offered_by_character
  do
    local api, count = battleNet({
      {
        battleTag = "Pal#1234",
        gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Bela", realmName = "Kazzak", wowProjectID = 1 },
      },
      {
        battleTag = "Other#1",
        gameAccountInfo = { isOnline = true, clientProgram = "WoW", characterName = "Csilla", realmName = "Kazzak", wowProjectID = 2 },
      },
      { battleTag = "App#9", gameAccountInfo = { isOnline = true, clientProgram = "BSAp" } },
    })
    local candidates = FriendCandidates.Collect({ battleNet = api, bnGetNumFriends = count, projectId = 1, localRealm = "Kazzak" })
    assert(#candidates == 1, "only friends in this same game, got " .. #candidates)
    assert(candidates[1].name == "Bela" and candidates[1].label == "Bela (Pal)", candidates[1].label)
  end

  -- test_self_excluded_and_duplicates_merged
  do
    local api, count = battleNet({
      { battleTag = "Pal#1", gameAccountInfo = { clientProgram = "WoW", characterName = "Anna", realmName = "Kazzak" } },
    })
    local candidates = FriendCandidates.Collect({
      friendList = friendList({ { name = "Anna", connected = false }, { name = "Me", connected = true }, { name = "Bela", connected = true } }),
      battleNet = api,
      bnGetNumFriends = count,
      localRealm = "Kazzak",
      selfName = "Me",
      exclude = { "bela" },
    })
    assert(#candidates == 1 and candidates[1].name == "Anna", "self and excluded names are left out, Anna once")
    assert(candidates[1].online == true, "online through Battle.net counts")
  end

  -- test_older_clients_use_the_global_friend_functions
  do
    local candidates = FriendCandidates.Collect({
      getNumFriends = function()
        return 1
      end,
      getFriendInfo = function()
        return "Anna", 60, "Mage", "Orgrimmar", true
      end,
    })
    assert(#candidates == 1 and candidates[1].name == "Anna" and candidates[1].online)
  end

  -- test_no_api_no_candidates
  do
    assert(#FriendCandidates.Collect({}) == 0)
  end
end
