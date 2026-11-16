-- Fake Retail-shaped C_BattleNet over a friend list, with call counters.
local FriendList = {}

-- state: "wow" (in WoW on a character), "app" (Battle.net app only) or
-- "offline". Retail has no top-level isOnline; presence is on gameAccountInfo.
function FriendList.AccountInfo(id, state)
  local game = { isOnline = state ~= "offline", clientProgram = state == "wow" and "WoW" or "App", gameAccountID = id }
  if state == "wow" then
    game.characterName = "Char" .. id
    game.playerGuid = "Player-1-" .. id
  end
  return { bnetAccountID = id, battleTag = "Tag#" .. id, isAFK = false, isDND = false, gameAccountInfo = game }
end

-- states[i] is the state of friend i, whose account ID is i and battle tag
-- "Tag#i". Returns api, calls; calls counts accountById, friendInfo and
-- numGameAccounts. Change states[i] to change what the API answers next.
function FriendList.NewApi(states)
  local calls = { accountById = 0, friendInfo = 0, numGameAccounts = 0 }
  local api = {
    GetNumFriends = function()
      return #states
    end,
    GetAccountInfoByID = function(id)
      calls.accountById = calls.accountById + 1
      return states[id] and FriendList.AccountInfo(id, states[id]) or nil
    end,
    GetFriendAccountInfo = function(i)
      calls.friendInfo = calls.friendInfo + 1
      return states[i] and FriendList.AccountInfo(i, states[i]) or nil
    end,
    GetFriendNumGameAccounts = function(i)
      calls.numGameAccounts = calls.numGameAccounts + 1
      return states[i] == "offline" and 0 or 1
    end,
    GetFriendGameAccountInfo = function(i, _j)
      return FriendList.AccountInfo(i, states[i]).gameAccountInfo
    end,
  }
  return api, calls
end

-- A Battle.net contact item for friend id.
function FriendList.Contact(id)
  return { conversationKey = "bnet::Tag#" .. id, channel = "BN", bnetAccountID = id, battleTag = "Tag#" .. id, displayName = "Tag#" .. id }
end

return FriendList
