local BNetResolver = require("WhisperMessenger.Transport.BNetResolver")

-- A Battle.net friend logged into three "game accounts" simultaneously:
-- the Battle.net app itself, WoW (with a live character), and an offline game.
local APP_ACCOUNT = { isOnline = true, isGameAFK = true }
local WOW_ACCOUNT = {
  characterName = "Redfer",
  realmName = "Kazzak",
  areaName = "Silvermoon City",
  isOnline = true,
  className = "Rogue",
  factionName = "Horde",
}
local OFFLINE_ACCOUNT = { isOnline = false }

local function buildApi(stage1GameAccountInfo)
  return {
    GetAccountInfoByID = function(_id)
      return { isOnline = nil, gameAccountInfo = stage1GameAccountInfo, battleTag = "Nergrom#2503" }
    end,
    GetNumFriends = function()
      return 1
    end,
    GetFriendAccountInfo = function(_index)
      return {
        bnetAccountID = 14,
        battleTag = "Nergrom#2503",
        isOnline = nil,
        gameAccountInfo = stage1GameAccountInfo,
      }
    end,
    GetFriendNumGameAccounts = function(_friendIndex)
      return 3
    end,
    GetFriendGameAccountInfo = function(_friendIndex, gameIndex)
      if gameIndex == 1 then
        return APP_ACCOUNT
      elseif gameIndex == 2 then
        return WOW_ACCOUNT
      elseif gameIndex == 3 then
        return OFFLINE_ACCOUNT
      end
    end,
    GetAccountInfoByGUID = function(_guid)
      return nil
    end,
  }
end

return function()
  -- Stage 1 already carries a WoW gameAccountInfo (Redfer); the app/offline
  -- accounts discovered while probing must not clobber it.
  do
    local api = buildApi(WOW_ACCOUNT)
    local scans = 0
    api.GetNumFriends = function()
      scans = scans + 1
      return 1
    end
    local result = BNetResolver.ResolveAccountInfo(api, 14, nil, "Nergrom#2503")
    assert(result ~= nil, "should resolve account info")
    assert(result.isOnline == true, "friend online in WoW should be online")
    assert(
      result.gameAccountInfo and result.gameAccountInfo.characterName == "Redfer",
      "gameAccountInfo should be the WoW character, not the app account"
    )
    assert(result.gameAccountInfo.areaName == "Silvermoon City", "should keep the WoW character's zone")
    assert(scans == 0, "complete live WoW presence must not scan the friend list")
  end

  -- Stage 1 has no gameAccountInfo at all; probing the friend's game accounts
  -- must still pick the WoW character over the app account.
  do
    local api = buildApi(nil)
    local result = BNetResolver.ResolveAccountInfo(api, 14, nil, "Nergrom#2503")
    assert(result ~= nil, "should resolve account info")
    assert(result.isOnline == true, "friend online in WoW should be online")
    assert(
      result.gameAccountInfo and result.gameAccountInfo.characterName == "Redfer",
      "gameAccountInfo should be the WoW character even with no stage-1 hint"
    )
  end

  -- An app account can hide a simultaneous WoW session; keep probing it.
  do
    local result = BNetResolver.ResolveAccountInfo(buildApi(APP_ACCOUNT), 14, nil, "Nergrom#2503")
    assert(result.gameAccountInfo.characterName == "Redfer", "app presence must still resolve the live WoW character")
  end

  -- No WoW character anywhere, only the Battle.net app online: falling back
  -- to the app account must still work.
  do
    local appOnlyApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, gameAccountInfo = nil, battleTag = "Nergrom#2503" }
      end,
      GetNumFriends = function()
        return 1
      end,
      GetFriendAccountInfo = function(_index)
        return { bnetAccountID = 14, battleTag = "Nergrom#2503", isOnline = nil, gameAccountInfo = nil }
      end,
      GetFriendNumGameAccounts = function(_friendIndex)
        return 1
      end,
      GetFriendGameAccountInfo = function(_friendIndex, gameIndex)
        if gameIndex == 1 then
          return APP_ACCOUNT
        end
      end,
      GetAccountInfoByGUID = function(_guid)
        return nil
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(appOnlyApi, 14, nil, "Nergrom#2503")
    assert(result ~= nil, "should resolve account info")
    assert(result.isOnline == true, "app-only friend should still be online")
    assert(result.gameAccountInfo == APP_ACCOUNT, "should fall back to the app account when no character exists")
  end
end
