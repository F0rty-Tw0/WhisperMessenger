local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Types = ns.TransportTypes or require("WhisperMessenger.Transport.Types")
local BNetResolver = {}

-- Stage 1: Primary lookup by bnetAccountID.
-- Returns accountInfo, isStaleId.
local function lookupByAccountId(bnetApi, bnetAccountID, guid, expectedBattleTag)
  if type(bnetApi.GetAccountInfoByID) ~= "function" then
    return nil, false
  end
  local ok, info = pcall(bnetApi.GetAccountInfoByID, bnetAccountID, guid)
  if not ok or not info then
    return nil, false
  end
  -- Detect stale bnetAccountID: stored ID now belongs to a different person
  if expectedBattleTag and info.battleTag and info.battleTag ~= expectedBattleTag then
    return nil, true
  end
  return info, false
end

-- Stage 3: Scan friend list to find entry matching bnetAccountID.
-- Returns accountInfo, friendIndex.
local function scanFriendListById(bnetApi, bnetAccountID)
  if type(bnetApi.GetNumFriends) ~= "function" or type(bnetApi.GetFriendAccountInfo) ~= "function" then
    return nil, nil
  end
  local ok, numFriends = pcall(bnetApi.GetNumFriends)
  if not ok or not numFriends then
    return nil, nil
  end
  for i = 1, numFriends do
    local ok2, info = pcall(bnetApi.GetFriendAccountInfo, i)
    if ok2 and info and info.bnetAccountID == bnetAccountID then
      if info.isOnline ~= nil then
        return info, i
      end
      return info, i
    end
  end
  return nil, nil
end

-- Stage 4: Iterate game accounts to detect online status when isOnline is nil.
-- Mutates accountInfo.isOnline and accountInfo.gameAccountInfo on success.
-- Returns enriched accountInfo if an active game account is found, otherwise nil.
local function probeGameAccounts(bnetApi, friendIndex, accountInfo)
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
  for j = 1, numAccounts do
    local ok2, gameInfo = pcall(bnetApi.GetFriendGameAccountInfo, friendIndex, j)
    if ok2 and gameInfo and (gameInfo.isOnline or gameInfo.characterName) then
      accountInfo.isOnline = true
      accountInfo.gameAccountInfo = gameInfo
      return accountInfo
    end
  end
  return nil
end

-- Stage 5: GUID fallback.
-- Handles two cases:
--   a) Different person (shifted ID): return ByGUID result if online.
--   b) Same person (matching or missing battleTag): merge useful fields into accountInfo.
--   c) Stale ID with no accountInfo: return ByGUID result unconditionally.
-- Returns resolved accountInfo or nil.
local function resolveByGUID(bnetApi, guid, accountInfo, isStaleId)
  if not guid or type(bnetApi.GetAccountInfoByGUID) ~= "function" then
    return nil
  end

  -- Stale ID with no prior accountInfo: direct GUID lookup, return unconditionally
  if isStaleId and accountInfo == nil then
    local ok, info = pcall(bnetApi.GetAccountInfoByGUID, guid)
    if ok and info then
      return info
    end
    return nil
  end

  -- Normal GUID fallback: only when accountInfo exists and isOnline is still nil
  if not accountInfo or accountInfo.isOnline ~= nil then
    return nil
  end

  local ok, info = pcall(bnetApi.GetAccountInfoByGUID, guid)
  if not ok or not info then
    return nil
  end

  local isDifferentPerson = info.battleTag and accountInfo.battleTag and info.battleTag ~= accountInfo.battleTag

  if isDifferentPerson then
    -- bnetAccountID has shifted to a different person between sessions;
    -- the GUID-based lookup is authoritative for the stored contact.
    local gameInfo = info.gameAccountInfo
    if info.isOnline or info.isAFK or info.isDND or (gameInfo and (gameInfo.isOnline or gameInfo.characterName)) then
      return info
    end
    return nil
  else
    -- Same person: merge useful fields from ByGUID result into accountInfo
    local gameInfo = info.gameAccountInfo
    if info.isOnline or (gameInfo and (gameInfo.isOnline or gameInfo.characterName)) then
      if gameInfo then
        accountInfo.gameAccountInfo = gameInfo
      end
      accountInfo.isOnline = info.isOnline
      -- If isOnline is still nil but game data proves online, set it
      if accountInfo.isOnline == nil and gameInfo and (gameInfo.isOnline or gameInfo.characterName) then
        accountInfo.isOnline = true
      end
      -- Preserve AFK/DND flags from whichever source has them
      if info.isAFK then
        accountInfo.isAFK = true
      end
      if info.isDND then
        accountInfo.isDND = true
      end
      return accountInfo
    end
    return nil
  end
end

function BNetResolver.ResolveFriendByBattleTag(bnetApi, battleTag, guid)
  if type(bnetApi.GetNumFriends) ~= "function" or type(bnetApi.GetFriendAccountInfo) ~= "function" then
    return nil
  end
  local ok, numFriends = pcall(bnetApi.GetNumFriends)
  if not ok or not numFriends then
    return nil
  end
  local friendIndex
  local accountInfo
  for i = 1, numFriends do
    local ok2, info = pcall(bnetApi.GetFriendAccountInfo, i)
    if ok2 and info and info.battleTag == battleTag then
      if info.isOnline ~= nil then
        return info
      end
      accountInfo = info
      friendIndex = i
      break
    end
  end
  -- Try game account iteration if found but isOnline=nil
  local enriched = probeGameAccounts(bnetApi, friendIndex, accountInfo)
  if enriched then
    return enriched
  end
  -- Try GUID fallback
  if guid and type(bnetApi.GetAccountInfoByGUID) == "function" then
    local ok2, info = pcall(bnetApi.GetAccountInfoByGUID, guid)
    if ok2 and info and info.battleTag == battleTag then
      local gameInfo = info.gameAccountInfo
      if info.isOnline or info.isAFK or info.isDND or (gameInfo and (gameInfo.isOnline or gameInfo.characterName)) then
        return info
      end
    end
  end
  return accountInfo
end

function BNetResolver.ResolveAccountInfo(bnetApi, bnetAccountID, guid, expectedBattleTag)
  if bnetApi == nil or bnetAccountID == nil then
    return nil
  end

  -- Stage 1: Primary lookup by bnetAccountID
  local accountInfo, isStaleId = lookupByAccountId(bnetApi, bnetAccountID, guid, expectedBattleTag)
  if accountInfo and accountInfo.isOnline ~= nil and not isStaleId then
    return accountInfo
  end

  -- Stage 2: Stale ID recovery via battleTag scan
  if isStaleId then
    local resolved = BNetResolver.ResolveFriendByBattleTag(bnetApi, expectedBattleTag, guid)
    if resolved then
      return resolved
    end
    -- Fall through to GUID fallback below with accountInfo=nil
  end

  -- Stage 3: Friend list scan by bnetAccountID (skip when stale)
  if not isStaleId then
    local scannedInfo, friendIndex = scanFriendListById(bnetApi, bnetAccountID)
    if scannedInfo and scannedInfo.isOnline ~= nil then
      return scannedInfo
    end
    accountInfo = accountInfo or scannedInfo

    -- Stage 4: Game account probing
    if friendIndex and accountInfo and accountInfo.isOnline == nil then
      local enriched = probeGameAccounts(bnetApi, friendIndex, accountInfo)
      if enriched then
        return enriched
      end
    end
  end

  -- Stage 5: GUID fallback
  local guidResult = resolveByGUID(bnetApi, guid, accountInfo, isStaleId)
  if guidResult then
    return guidResult
  end

  return accountInfo
end

function BNetResolver.ResolvePlayerInfo(playerInfoByGUID, guid)
  if type(playerInfoByGUID) ~= "function" or guid == nil then
    return nil
  end

  local ok, className, classTag, raceName, raceTag = pcall(playerInfoByGUID, guid)
  if not ok then
    return nil
  end

  if className == nil and classTag == nil and raceName == nil and raceTag == nil then
    return nil
  end

  return {
    className = className,
    classTag = classTag,
    raceName = raceName,
    raceTag = raceTag,
  }
end

function BNetResolver.ScanFriendList(bnetApi)
  local byBattleTag = {}
  if
    type(bnetApi) ~= "table"
    or type(bnetApi.GetNumFriends) ~= "function"
    or type(bnetApi.GetFriendAccountInfo) ~= "function"
  then
    return byBattleTag
  end
  local ok, numFriends = pcall(bnetApi.GetNumFriends)
  if not ok or not numFriends then
    return byBattleTag
  end
  for i = 1, numFriends do
    local ok2, info = pcall(bnetApi.GetFriendAccountInfo, i)
    if ok2 and info and info.battleTag then
      byBattleTag[info.battleTag] = {
        bnetAccountID = info.bnetAccountID,
        friendIndex = i,
        accountInfo = info,
      }
    end
  end
  return byBattleTag
end

function BNetResolver.NormalizeAvailabilityStatus(status)
  if status == nil or type(status) == "string" then
    return status
  end

  return Types.AVAILABILITY_STATUS_BY_CODE[status] or tostring(status)
end

ns.BNetResolver = BNetResolver

return BNetResolver
