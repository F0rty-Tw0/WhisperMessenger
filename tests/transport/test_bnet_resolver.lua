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

  -- NormalizeAvailabilityStatus
  assert(BNetResolver.NormalizeAvailabilityStatus(nil) == nil, "nil should return nil")
  assert(BNetResolver.NormalizeAvailabilityStatus("CanWhisper") == "CanWhisper", "string should pass through")
  assert(BNetResolver.NormalizeAvailabilityStatus(42) == "42", "unknown code should stringify")
end
