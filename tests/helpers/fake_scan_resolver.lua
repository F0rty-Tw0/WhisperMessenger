-- BNetResolver stand-in for Battle.net friend scan tests that hand the scan
-- a ready friend map.
local FakeScanResolver = {}

-- scanFriendList: returns the friend map (battleTag -> { bnetAccountID,
-- accountInfo }). An account resolves to the accountInfo of its battle tag in
-- the last scanned map, which is what the real resolver answers for a friend
-- whose primary game account is the one the window shows; no account ID or
-- no friend with that battle tag resolves to nil.
function FakeScanResolver.New(scanFriendList)
  local friendMap = {}
  return {
    ScanFriendList = function(bnetApi)
      friendMap = scanFriendList(bnetApi)
      return friendMap
    end,
    NewPassCache = function()
      return {}
    end,
    ResolveAccountInfo = function(_bnetApi, bnetAccountID, _guid, battleTag)
      local friend = bnetAccountID ~= nil and friendMap[battleTag] or nil
      return friend and friend.accountInfo or nil
    end,
  }
end

return FakeScanResolver
