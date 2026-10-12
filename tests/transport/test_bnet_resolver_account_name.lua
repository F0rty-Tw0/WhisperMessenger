local BNetResolver = require("WhisperMessenger.Transport.BNetResolver")
local AccountName = require("WhisperMessenger.Transport.BNetResolver.AccountName")

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

  local savedGlobal = rawget(_G, "BNGetNumFriends")
  local function globalCount()
    return 0
  end

  -- test_get_num_friends_prefers_the_api_table

  do
    rawset(_G, "BNGetNumFriends", globalCount)
    local api = buildApi()
    assert(AccountName.ResolveGetNumFriends(api) == api.GetNumFriends, "the api table's GetNumFriends must win")
  end

  -- test_get_num_friends_falls_back_to_the_global

  do
    rawset(_G, "BNGetNumFriends", globalCount)
    assert(AccountName.ResolveGetNumFriends({}) == globalCount, "BNGetNumFriends must be the fallback")
  end

  -- test_get_num_friends_nil_when_neither_exists

  do
    rawset(_G, "BNGetNumFriends", nil)
    assert(AccountName.ResolveGetNumFriends({}) == nil, "no friend count function must read as nil")
  end

  rawset(_G, "BNGetNumFriends", savedGlobal)
end
