local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Types = ns.TransportTypes or require("WhisperMessenger.Transport.Types")
local BNetResolver = {}

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
  if
    friendIndex
    and accountInfo
    and accountInfo.isOnline == nil
    and type(bnetApi.GetFriendNumGameAccounts) == "function"
    and type(bnetApi.GetFriendGameAccountInfo) == "function"
  then
    local ok3, numAccounts = pcall(bnetApi.GetFriendNumGameAccounts, friendIndex)
    if ok3 and numAccounts and numAccounts > 0 then
      for j = 1, numAccounts do
        local ok4, gameInfo = pcall(bnetApi.GetFriendGameAccountInfo, friendIndex, j)
        if ok4 and gameInfo and (gameInfo.isOnline or gameInfo.characterName) then
          accountInfo.isOnline = true
          accountInfo.gameAccountInfo = gameInfo
          return accountInfo
        end
      end
    end
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

  -- Primary: look up by BNet account ID
  local accountInfo
  local isStaleId = false
  if type(bnetApi.GetAccountInfoByID) == "function" then
    local ok, info = pcall(bnetApi.GetAccountInfoByID, bnetAccountID, guid)
    if ok and info then
      -- Detect stale bnetAccountID: stored ID now belongs to a different person
      if expectedBattleTag and info.battleTag and info.battleTag ~= expectedBattleTag then
        isStaleId = true
      elseif info.isOnline ~= nil then
        return info
      else
        accountInfo = info
      end
    end
  end

  -- When bnetAccountID is stale, resolve by battleTag instead
  if isStaleId then
    local resolved = BNetResolver.ResolveFriendByBattleTag(bnetApi, expectedBattleTag, guid)
    if resolved then
      return resolved
    end
    -- Fall through to GUID fallback below with accountInfo=nil
  end

  -- Fallback: scan friend list to find matching bnetAccountID (skip when stale)
  local friendIndex
  if
    not isStaleId
    and type(bnetApi.GetNumFriends) == "function"
    and type(bnetApi.GetFriendAccountInfo) == "function"
  then
    local ok, numFriends = pcall(bnetApi.GetNumFriends)
    if ok and numFriends then
      for i = 1, numFriends do
        local ok2, info = pcall(bnetApi.GetFriendAccountInfo, i)
        if ok2 and info and info.bnetAccountID == bnetAccountID then
          if info.isOnline ~= nil then
            return info
          end
          accountInfo = accountInfo or info
          friendIndex = i
          break
        end
      end
    end
  end

  -- Fallback: iterate game accounts to detect online status when isOnline is nil (skip when stale)
  if
    not isStaleId
    and friendIndex
    and accountInfo
    and accountInfo.isOnline == nil
    and type(bnetApi.GetFriendNumGameAccounts) == "function"
    and type(bnetApi.GetFriendGameAccountInfo) == "function"
  then
    local ok, numAccounts = pcall(bnetApi.GetFriendNumGameAccounts, friendIndex)
    if ok and numAccounts and numAccounts > 0 then
      for j = 1, numAccounts do
        local ok2, gameInfo = pcall(bnetApi.GetFriendGameAccountInfo, friendIndex, j)
        if ok2 and gameInfo and (gameInfo.isOnline or gameInfo.characterName) then
          accountInfo.isOnline = true
          accountInfo.gameAccountInfo = gameInfo
          return accountInfo
        end
      end
    end
  end

  -- Fallback: look up by GUID (returns different data path for some friends)
  -- Guard: reject if the GUID resolves to a clearly different person (different
  -- battleTag), which prevents cross-contamination of contact metadata.
  if accountInfo and accountInfo.isOnline == nil and guid and type(bnetApi.GetAccountInfoByGUID) == "function" then
    local ok, info = pcall(bnetApi.GetAccountInfoByGUID, guid)
    local isDifferentPerson = ok
      and info
      and info.battleTag
      and accountInfo.battleTag
      and info.battleTag ~= accountInfo.battleTag
    if ok and info and isDifferentPerson then
      -- bnetAccountID has shifted to a different person between sessions;
      -- the GUID-based lookup is authoritative for the stored contact.
      local gameInfo = info.gameAccountInfo
      if info.isOnline or info.isAFK or info.isDND or (gameInfo and (gameInfo.isOnline or gameInfo.characterName)) then
        return info
      end
    elseif ok and info and not isDifferentPerson then
      local gameInfo = info.gameAccountInfo
      if info.isOnline or (gameInfo and (gameInfo.isOnline or gameInfo.characterName)) then
        -- Merge useful fields from ByGUID result into accountInfo
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
    end
  end

  -- When stale and battleTag scan failed, try GUID path directly
  if isStaleId and accountInfo == nil and guid and type(bnetApi.GetAccountInfoByGUID) == "function" then
    local ok, info = pcall(bnetApi.GetAccountInfoByGUID, guid)
    if ok and info then
      local gameInfo = info.gameAccountInfo
      if info.isOnline or info.isAFK or info.isDND or (gameInfo and (gameInfo.isOnline or gameInfo.characterName)) then
        return info
      end
      return info
    end
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
