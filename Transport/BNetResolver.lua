local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Types = ns.TransportTypes or require("WhisperMessenger.Transport.Types")
local BNetResolver = {}

function BNetResolver.ResolveAccountInfo(bnetApi, bnetAccountID, guid)
  if bnetApi == nil or bnetAccountID == nil then
    return nil
  end

  -- Primary: look up by BNet account ID
  local accountInfo
  if type(bnetApi.GetAccountInfoByID) == "function" then
    local ok, info = pcall(bnetApi.GetAccountInfoByID, bnetAccountID, guid)
    if ok and info then
      -- If isOnline is explicitly set (true or false), trust the result
      if info.isOnline ~= nil then
        return info
      end
      accountInfo = info
    end
  end

  -- Fallback: scan friend list to find matching bnetAccountID
  if type(bnetApi.GetNumFriends) == "function" and type(bnetApi.GetFriendAccountInfo) == "function" then
    local ok, numFriends = pcall(bnetApi.GetNumFriends)
    if ok and numFriends then
      for i = 1, numFriends do
        local ok2, info = pcall(bnetApi.GetFriendAccountInfo, i)
        if ok2 and info and info.bnetAccountID == bnetAccountID then
          return info
        end
      end
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

function BNetResolver.NormalizeAvailabilityStatus(status)
  if status == nil or type(status) == "string" then
    return status
  end

  return Types.AVAILABILITY_STATUS_BY_CODE[status] or tostring(status)
end

ns.BNetResolver = BNetResolver

return BNetResolver
