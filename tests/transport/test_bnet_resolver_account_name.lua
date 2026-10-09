local BNetResolver = require("WhisperMessenger.Transport.BNetResolver")

local FRIENDS = {
  { accountName = "|Ks1|k", bnetAccountID = 12 },
  { accountName = "|Ks2|k", bnetAccountID = 7 },
}

local function buildApi()
  return {
    GetNumFriends = function()
      return #FRIENDS
    end,
    GetFriendAccountInfo = function(index)
      return FRIENDS[index]
    end,
  }
end

return function()
  -- test_resolves_bnet_account_id_by_kstring

  do
    local accountID = BNetResolver.ResolveAccountIDByAccountName(buildApi(), "|Ks2|k")
    assert(accountID == 7, "expected 7, got " .. tostring(accountID))
  end

  -- test_unknown_kstring_returns_nil

  do
    local accountID = BNetResolver.ResolveAccountIDByAccountName(buildApi(), "|Ks9|k")
    assert(accountID == nil, "unknown K-string should resolve to nil")
  end

  -- test_missing_api_returns_nil

  do
    local savedNum = _G.BNGetNumFriends
    _G.BNGetNumFriends = nil
    assert(BNetResolver.ResolveAccountIDByAccountName(nil, "|Ks1|k") == nil, "nil api should return nil")
    assert(BNetResolver.ResolveAccountIDByAccountName({}, "|Ks1|k") == nil, "empty api should return nil")
    _G.BNGetNumFriends = savedNum
  end

  -- test_does_not_parse_number_inside_kstring

  do
    local accountID = BNetResolver.ResolveAccountIDByAccountName(buildApi(), "|Ks1|k")
    assert(accountID == 12, "|Ks1|k must map to bnetAccountID 12, got " .. tostring(accountID))
  end
end
