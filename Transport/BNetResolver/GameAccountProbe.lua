local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Stage 4 of BNetResolver.ResolveAccountInfo: when the friend's account
-- reports isOnline=nil, walk their game accounts to prove presence.
local GameAccountProbe = {}

-- Picks the best game account from a friend's account list: prefers the
-- first entry with an actual WoW characterName (a Battle.net app or other
-- game account has none), falling back to the first isOnline entry only
-- when no account has a character.
local function pickGameAccount(bnetApi, friendIndex, numAccounts)
  local fallback
  for j = 1, numAccounts do
    local ok, gameInfo = pcall(bnetApi.GetFriendGameAccountInfo, friendIndex, j)
    if ok and gameInfo then
      if gameInfo.characterName and gameInfo.characterName ~= "" then
        return gameInfo
      end
      if not fallback and gameInfo.isOnline then
        fallback = gameInfo
      end
    end
  end
  return fallback
end

-- Iterate game accounts to detect online status when isOnline is nil.
-- Mutates accountInfo.isOnline and accountInfo.gameAccountInfo on success.
-- Returns enriched accountInfo if an active game account is found, otherwise nil.
function GameAccountProbe.Probe(bnetApi, friendIndex, accountInfo)
  if
    not friendIndex
    or not accountInfo
    or accountInfo.isOnline ~= nil
    or type(bnetApi.GetFriendNumGameAccounts) ~= "function"
    or type(bnetApi.GetFriendGameAccountInfo) ~= "function"
  then
    return nil
  end
  local ok, numAccounts = pcall(bnetApi.GetFriendNumGameAccounts, friendIndex)
  if not ok or not numAccounts or numAccounts <= 0 then
    return nil
  end
  local picked = pickGameAccount(bnetApi, friendIndex, numAccounts)
  if not picked then
    return nil
  end
  accountInfo.isOnline = true
  local existing = accountInfo.gameAccountInfo
  local existingHasCharacter = existing and existing.characterName and existing.characterName ~= ""
  local pickedHasCharacter = picked.characterName and picked.characterName ~= ""
  if not (existingHasCharacter and not pickedHasCharacter) then
    accountInfo.gameAccountInfo = picked
  end
  return accountInfo
end

ns.BNetResolverGameAccountProbe = GameAccountProbe
return GameAccountProbe
