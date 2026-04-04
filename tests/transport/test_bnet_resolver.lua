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
    assert(type(result) == "table", "expected primary account info table")
    assert(result.battleTag == "Primary#1111", "should use primary when isOnline is set")
  end

  -- ResolveAccountInfo falls back to game account iteration when isOnline=nil everywhere
  do
    local gameAccountApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, bnetAccountID = 88, battleTag = "AppOnly#1234" }
      end,
      GetNumFriends = function()
        return 2
      end,
      GetFriendAccountInfo = function(index)
        if index == 1 then
          return { bnetAccountID = 88, isOnline = nil }
        end
        return { bnetAccountID = 99 }
      end,
      GetFriendNumGameAccounts = function(_friendIndex)
        return 3
      end,
      GetFriendGameAccountInfo = function(_friendIndex, gameIndex)
        if gameIndex == 2 then
          return { isOnline = true, clientProgram = "BSAp" }
        end
        return { isOnline = false }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(gameAccountApi, 88)
    assert(result ~= nil, "game account fallback should return info")
    assert(result.isOnline == true, "game account fallback should set isOnline=true")
    assert(result.gameAccountInfo.clientProgram == "BSAp", "should return active game account info")
  end

  -- ResolveAccountInfo game account fallback skipped when no active game accounts
  do
    local noActiveApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, bnetAccountID = 77 }
      end,
      GetNumFriends = function()
        return 1
      end,
      GetFriendAccountInfo = function(_index)
        return { bnetAccountID = 77, isOnline = nil }
      end,
      GetFriendNumGameAccounts = function(_friendIndex)
        return 2
      end,
      GetFriendGameAccountInfo = function(_friendIndex, _gameIndex)
        return { isOnline = false }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(noActiveApi, 77)
    assert(result ~= nil, "should still return account info")
    assert(result.isOnline == nil, "should not set isOnline when no active game accounts")
  end

  -- ResolveAccountInfo falls back to GetAccountInfoByGUID when isOnline=nil
  do
    local byGuidApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, bnetAccountID = 16, battleTag = "Primary#1234", isAFK = false }
      end,
      GetNumFriends = function()
        return 1
      end,
      GetFriendAccountInfo = function(_index)
        return { bnetAccountID = 16, isOnline = nil }
      end,
      GetFriendNumGameAccounts = function(_fi)
        return 0
      end,
      GetFriendGameAccountInfo = function()
        return nil
      end,
      GetAccountInfoByGUID = function(_guid)
        return {
          isOnline = nil,
          isAFK = true,
          isDND = false,
          gameAccountInfo = { isOnline = true, characterName = "Deathrøse", factionName = "Horde" },
        }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(byGuidApi, 16, "Player-1305-0D65D962")
    assert(result ~= nil, "ByGUID fallback should return info")
    assert(result.isOnline == true, "ByGUID fallback should set isOnline=true, got: " .. tostring(result.isOnline))
    assert(result.isAFK == true, "ByGUID fallback should preserve isAFK")
    assert(result.gameAccountInfo.characterName == "Deathrøse", "ByGUID fallback should merge gameAccountInfo")
  end

  -- ResolveAccountInfo ByGUID fallback skipped when guid is nil
  do
    local noGuidApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, bnetAccountID = 88 }
      end,
      GetNumFriends = function()
        return 0
      end,
      GetAccountInfoByGUID = function(_guid)
        return { isOnline = true }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(noGuidApi, 88, nil)
    assert(result ~= nil, "should return primary info")
    assert(result.isOnline == nil, "should not use ByGUID without guid")
  end

  -- ResolveAccountInfo ByGUID fallback with shifted bnetAccountID returns ByGUID result
  -- (bnetAccountID shifted to Crowheart, but GUID belongs to Nergrom who is online)
  do
    local shiftedApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, battleTag = "Crowheart#2268" }
      end,
      GetNumFriends = function()
        return 1
      end,
      GetFriendAccountInfo = function(_index)
        return { bnetAccountID = 10, isOnline = nil }
      end,
      GetFriendNumGameAccounts = function(_fi)
        return 0
      end,
      GetFriendGameAccountInfo = function()
        return nil
      end,
      GetAccountInfoByGUID = function(_guid)
        return {
          bnetAccountID = 11,
          isOnline = true,
          battleTag = "Nergrom#2503",
          gameAccountInfo = {
            isOnline = true,
            characterName = "Nergrom",
            realmName = "Kazzak",
            factionName = "Horde",
          },
        }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(shiftedApi, 10, "Player-1305-08ACF728")
    assert(result ~= nil, "shifted ID should return ByGUID result")
    -- GUID is authoritative: should return the real person's data
    assert(
      result.battleTag == "Nergrom#2503",
      "shifted ID should return ByGUID person's battleTag, got: " .. tostring(result.battleTag)
    )
    assert(result.isOnline == true, "shifted ID should return ByGUID person's online status")
  end

  -- ResolveAccountInfo ByGUID fallback with shifted bnetAccountID but offline contact falls through
  do
    local shiftedOfflineApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, battleTag = "Crowheart#2268" }
      end,
      GetNumFriends = function()
        return 0
      end,
      GetAccountInfoByGUID = function(_guid)
        return {
          isOnline = nil,
          battleTag = "Nergrom#2503",
          gameAccountInfo = { isOnline = false, characterName = nil },
        }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(shiftedOfflineApi, 10, "Player-1305-08ACF728")
    assert(result ~= nil, "shifted ID with offline ByGUID should return primary")
    assert(
      result.battleTag == "Crowheart#2268",
      "shifted ID offline should keep primary, got: " .. tostring(result.battleTag)
    )
  end

  -- ResolveAccountInfo ByGUID fallback merges same-person data (matching battleTag)
  do
    local samePersonApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, battleTag = "Palapop#2189" }
      end,
      GetNumFriends = function()
        return 1
      end,
      GetFriendAccountInfo = function(_index)
        return { bnetAccountID = 2, isOnline = nil }
      end,
      GetFriendNumGameAccounts = function(_fi)
        return 0
      end,
      GetFriendGameAccountInfo = function()
        return nil
      end,
      GetAccountInfoByGUID = function(_guid)
        return {
          isOnline = nil,
          battleTag = "Palapop#2189",
          gameAccountInfo = {
            isOnline = true,
            characterName = "Stormdream",
            factionName = "Alliance",
          },
        }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(samePersonApi, 2, "Player-1597-0CE0FFA7")
    assert(result ~= nil, "same-person ByGUID should return info")
    assert(result.isOnline == true, "same-person ByGUID should set isOnline=true")
    assert(result.gameAccountInfo.characterName == "Stormdream", "same-person ByGUID should merge gameAccountInfo")
  end

  -- ResolveAccountInfo detects stale bnetAccountID via expectedBattleTag and scans by battleTag
  do
    local staleApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, battleTag = "Mentis#2390" }
      end,
      GetNumFriends = function()
        return 3
      end,
      GetFriendAccountInfo = function(index)
        if index == 1 then
          return { bnetAccountID = 5, battleTag = "Alpha#1111", isOnline = true }
        elseif index == 2 then
          return { bnetAccountID = 22, battleTag = "Nergrom#2503", isOnline = true }
        elseif index == 3 then
          return { bnetAccountID = 11, battleTag = "Mentis#2390", isOnline = true }
        end
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(staleApi, 11, nil, "Nergrom#2503")
    assert(result ~= nil, "stale ID with battleTag scan should find correct friend")
    assert(
      result.battleTag == "Nergrom#2503",
      "stale ID should resolve to correct person by battleTag, got: " .. tostring(result.battleTag)
    )
    assert(result.isOnline == true, "stale ID should return correct person's online status")
  end

  -- ResolveAccountInfo with matching expectedBattleTag does not trigger stale detection
  do
    local matchingApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = true, battleTag = "Nergrom#2503" }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(matchingApi, 11, nil, "Nergrom#2503")
    assert(result ~= nil, "matching battleTag should return normally")
    assert(result.battleTag == "Nergrom#2503", "matching battleTag should return same data")
    assert(result.isOnline == true, "matching battleTag should preserve isOnline")
  end

  -- ResolveAccountInfo without expectedBattleTag does not trigger stale detection (backward compat)
  do
    local noExpectedApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, battleTag = "Mentis#2390" }
      end,
      GetNumFriends = function()
        return 1
      end,
      GetFriendAccountInfo = function(_index)
        return { bnetAccountID = 11, isOnline = nil }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(noExpectedApi, 11, nil, nil)
    assert(result ~= nil, "no expectedBattleTag should still work")
    assert(result.battleTag == "Mentis#2390", "no expectedBattleTag should return ID-based result")
  end

  -- ResolveAccountInfo stale ID with friend not found falls through gracefully
  do
    local staleNotFoundApi = {
      GetAccountInfoByID = function(_id)
        return { isOnline = nil, battleTag = "Mentis#2390" }
      end,
      GetNumFriends = function()
        return 1
      end,
      GetFriendAccountInfo = function(_index)
        return { bnetAccountID = 11, battleTag = "Mentis#2390", isOnline = true }
      end,
    }
    local result = BNetResolver.ResolveAccountInfo(staleNotFoundApi, 11, nil, "Nergrom#2503")
    -- Nergrom not found in friend list, and no GUID — should return nil
    assert(
      result == nil,
      "stale ID with friend not found and no GUID should return nil, got: " .. tostring(result and result.battleTag)
    )
  end

  -- ScanFriendList returns lookup table by battleTag
  do
    local scanApi = {
      GetNumFriends = function()
        return 3
      end,
      GetFriendAccountInfo = function(index)
        if index == 1 then
          return { bnetAccountID = 5, battleTag = "Alpha#1111", isOnline = true }
        elseif index == 2 then
          return { bnetAccountID = 22, battleTag = "Nergrom#2503", isOnline = nil }
        elseif index == 3 then
          return { bnetAccountID = 11, battleTag = "Mentis#2390", isOnline = true }
        end
      end,
    }
    local result = BNetResolver.ScanFriendList(scanApi)
    assert(result["Nergrom#2503"] ~= nil, "should find Nergrom by battleTag")
    assert(result["Nergrom#2503"].bnetAccountID == 22, "should have correct bnetAccountID")
    assert(result["Nergrom#2503"].friendIndex == 2, "should have correct friendIndex")
    assert(result["Alpha#1111"] ~= nil, "should find Alpha")
    assert(result["Mentis#2390"] ~= nil, "should find Mentis")
  end

  -- ScanFriendList with nil API returns empty table
  do
    local result = BNetResolver.ScanFriendList(nil)
    local count = 0
    for _ in pairs(result) do
      count = count + 1
    end
    assert(count == 0, "nil API should return empty table")
  end

  -- ScanFriendList with empty friend list returns empty table
  do
    local emptyApi = {
      GetNumFriends = function()
        return 0
      end,
      GetFriendAccountInfo = function()
        return nil
      end,
    }
    local result = BNetResolver.ScanFriendList(emptyApi)
    local count = 0
    for _ in pairs(result) do
      count = count + 1
    end
    assert(count == 0, "empty friend list should return empty table")
  end

  -- ScanFriendList skips friends without battleTag
  do
    local partialApi = {
      GetNumFriends = function()
        return 2
      end,
      GetFriendAccountInfo = function(index)
        if index == 1 then
          return { bnetAccountID = 1, battleTag = nil }
        elseif index == 2 then
          return { bnetAccountID = 2, battleTag = "HasTag#1234" }
        end
      end,
    }
    local result = BNetResolver.ScanFriendList(partialApi)
    local count = 0
    for _ in pairs(result) do
      count = count + 1
    end
    assert(count == 1, "should only include friends with battleTag")
    assert(result["HasTag#1234"] ~= nil, "should include friend with battleTag")
  end

  -- NormalizeAvailabilityStatus
  assert(BNetResolver.NormalizeAvailabilityStatus(nil) == nil, "nil should return nil")
  assert(BNetResolver.NormalizeAvailabilityStatus("CanWhisper") == "CanWhisper", "string should pass through")
  assert(BNetResolver.NormalizeAvailabilityStatus(42) == "42", "unknown code should stringify")
end
