local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Types = ns.TransportTypes or require("WhisperMessenger.Transport.Types")
local BNetResolver = {}

function BNetResolver.ResolveAccountInfo(bnetApi, bnetAccountID, guid)
  if bnetApi == nil or type(bnetApi.GetAccountInfoByID) ~= "function" or bnetAccountID == nil then
    return nil
  end

  local ok, accountInfo = pcall(bnetApi.GetAccountInfoByID, bnetAccountID, guid)
  if not ok then
    return nil
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
