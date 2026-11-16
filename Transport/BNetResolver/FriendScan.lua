local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local AccountName = ns.BNetResolverAccountName or require("WhisperMessenger.Transport.BNetResolver.AccountName")

-- Uncached walks of the Battle.net friend list for BNetResolver: every call
-- asks the game again and stops at the first match. PassCache holds the
-- one-walk-per-pass variant of the same lookups.
local FriendScan = {}

local resolveGetNumFriends = AccountName.ResolveGetNumFriends

-- Returns the friend count, or nil when the friend list cannot be read.
function FriendScan.NumFriends(bnetApi)
  local getNumFriends = resolveGetNumFriends(bnetApi)
  if type(getNumFriends) ~= "function" or type(bnetApi.GetFriendAccountInfo) ~= "function" then
    return nil
  end
  local ok, numFriends = pcall(getNumFriends)
  if not ok or not numFriends then
    return nil
  end
  return numFriends
end

-- Stage 3: Scan friend list to find entry matching bnetAccountID.
-- sanitizeAccountID: BNetResolver.SanitizeAccountID, handed in because the
-- resolver loads after this file.
-- Returns accountInfo, friendIndex.
function FriendScan.ById(bnetApi, bnetAccountID, sanitizeAccountID)
  local numFriends = FriendScan.NumFriends(bnetApi)
  if numFriends == nil then
    return nil, nil
  end
  for i = 1, numFriends do
    local ok, info = pcall(bnetApi.GetFriendAccountInfo, i)
    if ok and info then
      local candidate = sanitizeAccountID(info.bnetAccountID)
      if candidate ~= nil and candidate == bnetAccountID then
        return info, i
      end
    end
  end
  return nil, nil
end

-- Scan friend list to find the entry matching battleTag.
-- Returns accountInfo, friendIndex, listAvailable (false: no readable list).
function FriendScan.ByBattleTag(bnetApi, battleTag)
  local numFriends = FriendScan.NumFriends(bnetApi)
  if numFriends == nil then
    return nil, nil, false
  end
  for i = 1, numFriends do
    local ok, info = pcall(bnetApi.GetFriendAccountInfo, i)
    if ok and info and info.battleTag == battleTag then
      return info, i, true
    end
  end
  return nil, nil, true
end

ns.BNetResolverFriendScan = FriendScan
return FriendScan
