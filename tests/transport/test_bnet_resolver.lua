local BNetResolver = require("WhisperMessenger.Transport.BNetResolver")

return function()
  -- ResolveAccountInfo with valid API
  local mockApi = {
    GetAccountInfoByID = function(id, guid)
      return { battleTag = "Test#1234", accountName = "Test" }
    end,
  }
  local info = BNetResolver.ResolveAccountInfo(mockApi, 42, "guid-1")
  assert(info ~= nil, "should resolve account info")
  assert(info.battleTag == "Test#1234", "should return battleTag")

  -- ResolveAccountInfo with nil API
  assert(BNetResolver.ResolveAccountInfo(nil, 42) == nil, "nil api should return nil")

  -- ResolveAccountInfo with missing function
  assert(BNetResolver.ResolveAccountInfo({}, 42) == nil, "missing func should return nil")

  -- ResolveAccountInfo with nil bnetAccountID
  assert(BNetResolver.ResolveAccountInfo(mockApi, nil) == nil, "nil id should return nil")

  -- ResolveAccountInfo with error
  local errorApi = {
    GetAccountInfoByID = function()
      error("api error")
    end,
  }
  assert(BNetResolver.ResolveAccountInfo(errorApi, 42) == nil, "error should return nil")

  -- ResolvePlayerInfo
  local mockPlayerInfo = function(guid)
    return "Warrior", "WARRIOR", "Orc", "Orc"
  end
  local playerInfo = BNetResolver.ResolvePlayerInfo(mockPlayerInfo, "guid-1")
  assert(playerInfo ~= nil, "should resolve player info")
  assert(playerInfo.className == "Warrior", "should return className")
  assert(playerInfo.classTag == "WARRIOR", "should return classTag")

  -- ResolvePlayerInfo with nil
  assert(BNetResolver.ResolvePlayerInfo(nil, "guid") == nil, "nil func should return nil")
  assert(BNetResolver.ResolvePlayerInfo(mockPlayerInfo, nil) == nil, "nil guid should return nil")

  -- ResolvePlayerInfo with all nil results
  local nilPlayerInfo = function(guid)
    return nil, nil, nil, nil
  end
  assert(BNetResolver.ResolvePlayerInfo(nilPlayerInfo, "guid") == nil, "all-nil should return nil")

  -- ResolveAccountInfo falls back to friend list scan when primary returns isOnline=nil
  do
    local fallbackApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, gameAccountInfo = { isOnline = false } }
      end,
      GetNumFriends = function()
        return 3
      end,
      GetFriendAccountInfo = function(index)
        if index == 2 then
          return { bnetAccountID = 55, isOnline = true, battleTag = "Found#1234" }
        end
        return { bnetAccountID = 99 }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(fallbackApi, 55)
    assert(result ~= nil, "fallback should return account info")
    assert(result.isOnline == true, "fallback should return online friend, got: " .. tostring(result.isOnline))
    assert(result.battleTag == "Found#1234", "fallback should return matching friend data")
  end

  -- ResolveAccountInfo does not fall back when primary returns isOnline=true
  do
    local primaryOkApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = true, battleTag = "Primary#1111" }
      end,
      GetNumFriends = function()
        return 1
      end,
      GetFriendAccountInfo = function(_index)
        return { bnetAccountID = 77, isOnline = true, battleTag = "Wrong#2222" }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(primaryOkApi, 77)
    assert(result.battleTag == "Primary#1111", "should use primary when isOnline is set")
  end

  -- NormalizeAvailabilityStatus
  assert(BNetResolver.NormalizeAvailabilityStatus(nil) == nil, "nil should return nil")
  assert(BNetResolver.NormalizeAvailabilityStatus("CanWhisper") == "CanWhisper", "string should pass through")
  assert(BNetResolver.NormalizeAvailabilityStatus(42) == "42", "unknown code should stringify")
end
