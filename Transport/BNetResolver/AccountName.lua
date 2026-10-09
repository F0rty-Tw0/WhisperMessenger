local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Maps a Battle.net K-string sender name (what GetChatLineSenderName returns
-- for a Battle.net line, e.g. "|Ks1|k") to the friend's bnetAccountID. The
-- number inside the K-string is not the account ID, so the only reliable
-- match is the friend list's own accountName.
local AccountName = {}

local function resolveGetNumFriends(bnetApi)
  if type(bnetApi.GetNumFriends) == "function" then
    return bnetApi.GetNumFriends
  end
  if type(_G.BNGetNumFriends) == "function" then
    return _G.BNGetNumFriends
  end
end

function AccountName.Resolve(bnetApi, accountName)
  if type(bnetApi) ~= "table" or type(accountName) ~= "string" or accountName == "" then
    return nil
  end
  local getNumFriends = resolveGetNumFriends(bnetApi)
  if getNumFriends == nil or type(bnetApi.GetFriendAccountInfo) ~= "function" then
    return nil
  end
  local ok, numFriends = pcall(getNumFriends)
  if not ok or type(numFriends) ~= "number" then
    return nil
  end
  for i = 1, numFriends do
    local okInfo, info = pcall(bnetApi.GetFriendAccountInfo, i)
    if okInfo and type(info) == "table" and info.accountName == accountName then
      return info.bnetAccountID
    end
  end
  return nil
end

ns.BNetResolverAccountName = AccountName
return AccountName
