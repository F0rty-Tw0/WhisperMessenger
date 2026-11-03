local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Types = ns.TransportTypes or require("WhisperMessenger.Transport.Types")
local AccountName = ns.BNetResolverAccountName or require("WhisperMessenger.Transport.BNetResolver.AccountName")
-- stylua: ignore start
local GameAccountProbe = ns.BNetResolverGameAccountProbe or require("WhisperMessenger.Transport.BNetResolver.GameAccountProbe")
local GuidFallback = ns.BNetResolverGuidFallback or require("WhisperMessenger.Transport.BNetResolver.GuidFallback")
-- stylua: ignore end
local BNetResolver = {}

-- Stage 1: Primary lookup by bnetAccountID.
-- Returns accountInfo, isStaleId.
-- NOTE: GetAccountInfoByID's second argument is a WoW *account* GUID, not a
-- character GUID. Passing a character GUID (Player-XXXX-XXXXX) causes the API
-- to return filtered data with isOnline=nil when that character is not
-- currently logged in, hiding the friend's actual presence on other characters.
-- We always omit the second argument to get the friend's primary account state.
local function lookupByAccountId(bnetApi, bnetAccountID, _guid, expectedBattleTag)
  if type(bnetApi.GetAccountInfoByID) ~= "function" then
    return nil, false
  end
  local ok, info = pcall(bnetApi.GetAccountInfoByID, bnetAccountID)
  if not ok or not info then
    return nil, false
  end
  -- Detect stale bnetAccountID: stored ID now belongs to a different person
  if expectedBattleTag and info.battleTag and info.battleTag ~= expectedBattleTag then
    return nil, true
  end
  -- Retail exposes presence on gameAccountInfo, not the legacy account field.
  -- A live WoW character is already the preferred result; do not scan the
  -- roster to rediscover it. App-only data still needs multi-account probing.
  local gameInfo = info.gameAccountInfo
  if
    info.isOnline == nil
    and gameInfo
    and gameInfo.isOnline == true
    and type(gameInfo.characterName) == "string"
    and gameInfo.characterName ~= ""
  then
    info.isOnline = true
  end
  return info, false
end

local resolveGetNumFriends = AccountName.ResolveGetNumFriends
local probeGameAccounts = GameAccountProbe.Probe
local resolveByGUID = GuidFallback.Resolve

function BNetResolver.SanitizeAccountID(value)
  local issecretvalue = _G.issecretvalue
  if type(issecretvalue) == "function" then
    local ok, isSecret = pcall(issecretvalue, value)
    if not ok or isSecret then
      return nil
    end
  end
  if value == nil then
    return nil
  end
  return value
end

function BNetResolver.ResolveAccountInfoByGameAccountID(bnetApi, gameAccountID)
  if type(bnetApi) ~= "table" then
    return nil
  end
  gameAccountID = BNetResolver.SanitizeAccountID(gameAccountID)
  if gameAccountID == nil or type(bnetApi.GetGameAccountInfoByID) ~= "function" then
    return nil
  end

  local gameCallSucceeded, gameAccountInfo = pcall(bnetApi.GetGameAccountInfoByID, gameAccountID)
  if not gameCallSucceeded or type(gameAccountInfo) ~= "table" then
    return nil
  end

  local playerGuid = BNetResolver.SanitizeAccountID(gameAccountInfo.playerGuid)
  if playerGuid == nil or type(bnetApi.GetAccountInfoByGUID) ~= "function" then
    return nil
  end

  local accountCallSucceeded, accountInfo = pcall(bnetApi.GetAccountInfoByGUID, playerGuid)
  if not accountCallSucceeded or type(accountInfo) ~= "table" then
    return nil
  end

  local bnetAccountID = BNetResolver.SanitizeAccountID(accountInfo.bnetAccountID)
  if bnetAccountID == nil then
    return nil
  end
  accountInfo.bnetAccountID = bnetAccountID
  return accountInfo
end

-- Stage 3: Scan friend list to find entry matching bnetAccountID.
-- Returns accountInfo, friendIndex.
local function scanFriendListById(bnetApi, bnetAccountID)
  local getNumFriends = resolveGetNumFriends(bnetApi)
  if type(getNumFriends) ~= "function" or type(bnetApi.GetFriendAccountInfo) ~= "function" then
    return nil, nil
  end
  local ok, numFriends = pcall(getNumFriends)
  if not ok or not numFriends then
    return nil, nil
  end
  for i = 1, numFriends do
    local ok2, info = pcall(bnetApi.GetFriendAccountInfo, i)
    if ok2 and info then
      local candidate = BNetResolver.SanitizeAccountID(info.bnetAccountID)
      if candidate ~= nil and candidate == bnetAccountID then
        if info.isOnline ~= nil then
          return info, i
        end
        return info, i
      end
    end
  end
  return nil, nil
end

function BNetResolver.ResolveFriendByBattleTag(bnetApi, battleTag, guid)
  local getNumFriends = resolveGetNumFriends(bnetApi)
  if type(getNumFriends) ~= "function" or type(bnetApi.GetFriendAccountInfo) ~= "function" then
    return nil
  end
  local ok, numFriends = pcall(getNumFriends)
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
      -- isAFK/isDND are STICKY and persist after offline — not valid proof of presence.
      local gameInfo = info.gameAccountInfo
      if info.isOnline == true or (gameInfo and (gameInfo.isOnline or gameInfo.characterName)) then
        return info
      end
    end
  end
  return accountInfo
end

function BNetResolver.ResolveAccountInfo(bnetApi, bnetAccountID, guid, expectedBattleTag)
  if bnetApi == nil then
    return nil
  end
  bnetAccountID = BNetResolver.SanitizeAccountID(bnetAccountID)
  if bnetAccountID == nil then
    return nil
  end

  -- Stage 1: Primary lookup by bnetAccountID
  local accountInfo, isStaleId = lookupByAccountId(bnetApi, bnetAccountID, guid, expectedBattleTag)
  if accountInfo and accountInfo.isOnline ~= nil and not isStaleId then
    return accountInfo
  end

  -- Stage 2: Stale or missing ID recovery via battleTag scan
  if expectedBattleTag and (isStaleId or accountInfo == nil) then
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
  if type(bnetApi) ~= "table" then
    return byBattleTag
  end
  local getNumFriends = resolveGetNumFriends(bnetApi)
  if type(getNumFriends) ~= "function" or type(bnetApi.GetFriendAccountInfo) ~= "function" then
    return byBattleTag
  end
  local ok, numFriends = pcall(getNumFriends)
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

BNetResolver.ResolveAccountIDByAccountName = AccountName.Resolve

ns.BNetResolver = BNetResolver

return BNetResolver
