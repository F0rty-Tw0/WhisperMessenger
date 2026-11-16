-- One Battle.net friend with one conversation, for friend scan tests that
-- run the real resolver against a fake C_BattleNet.
local ScanWorld = {}

ScanWorld.FRIEND_KEY = "bnet::friend"
ScanWorld.BATTLE_TAG = "Friend#1234"
ScanWorld.ACCOUNT_ID = 42

local function copy(source)
  local out = {}
  for field, value in pairs(source) do
    out[field] = value
  end
  return out
end

-- A game account in WoW on a character.
function ScanWorld.WowAccount(characterName)
  return { isOnline = true, clientProgram = "WoW", characterName = characterName, realmName = "Area52", areaName = "Dornogal" }
end

-- A game account in the Battle.net app: online, no character.
function ScanWorld.AppAccount()
  return { isOnline = true, clientProgram = "App" }
end

-- account: the friend's account fields. gameAccounts: their game accounts in
-- friend-list order; the first one is the account's primary gameAccountInfo.
-- Every answer is a fresh table, like the game's. Change account or
-- gameAccounts to change what the API answers next.
function ScanWorld.NewApi(account, gameAccounts)
  local function accountInfo()
    local info = copy(account)
    info.gameAccountInfo = gameAccounts[1] and copy(gameAccounts[1]) or nil
    return info
  end
  return {
    GetNumFriends = function()
      return 1
    end,
    GetFriendAccountInfo = accountInfo,
    GetAccountInfoByID = accountInfo,
    GetAccountInfoByGUID = accountInfo,
    GetFriendNumGameAccounts = function()
      return #gameAccounts
    end,
    GetFriendGameAccountInfo = function(_friendIndex, index)
      return gameAccounts[index] and copy(gameAccounts[index]) or nil
    end,
  }
end

function ScanWorld.Account()
  return { bnetAccountID = ScanWorld.ACCOUNT_ID, battleTag = ScanWorld.BATTLE_TAG, isAFK = false }
end

-- conversationFields: extra fields for the friend's stored conversation.
function ScanWorld.Store(conversationFields)
  local conversation = {
    channel = "BN",
    battleTag = ScanWorld.BATTLE_TAG,
    bnetAccountID = ScanWorld.ACCOUNT_ID,
    displayName = ScanWorld.BATTLE_TAG,
    messages = {},
  }
  for field, value in pairs(conversationFields or {}) do
    conversation[field] = value
  end
  return { conversations = { [ScanWorld.FRIEND_KEY] = conversation } }
end

-- A Bootstrap whose runtime.refreshWindow records each call's dirty keys
-- (false for nil: the full rebuild). Returns Bootstrap, refreshes.
function ScanWorld.Bootstrap(bnetApi, store, visible)
  local refreshes = {}
  local Bootstrap = {
    runtime = {
      bnetApi = bnetApi,
      store = store,
      isWindowVisible = function()
        return visible
      end,
      refreshWindow = function(_focusKey, dirtyKeys)
        refreshes[#refreshes + 1] = dirtyKeys or false
      end,
    },
  }
  return Bootstrap, refreshes
end

return ScanWorld
