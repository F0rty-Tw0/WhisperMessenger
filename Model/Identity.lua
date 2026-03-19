local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = {}

local function normalizeName(name)
  return string.lower(name or "")
end

local function buildGameAccountName(accountInfo)
  local gameAccountInfo = accountInfo and accountInfo.gameAccountInfo or nil
  if gameAccountInfo == nil then
    return nil
  end

  local characterName = gameAccountInfo.characterName
  local realmName = gameAccountInfo.realmName or gameAccountInfo.realmDisplayName
  if characterName and realmName then
    return characterName .. "-" .. realmName
  end

  return characterName or realmName
end

function Identity.FromWhisper(fullName, guid)
  return {
    channel = "WOW",
    contactKey = "WOW::" .. normalizeName(fullName),
    canonicalName = normalizeName(fullName),
    displayName = fullName,
    guid = guid,
  }
end

function Identity.FromBattleNet(bnetAccountID, accountInfo)
  local gameAccountName = buildGameAccountName(accountInfo)
  local gameAccountInfo = accountInfo and accountInfo.gameAccountInfo or nil

  return {
    channel = "BN",
    contactKey = "BN::" .. tostring(bnetAccountID),
    canonicalName = tostring(bnetAccountID),
    displayName = (accountInfo and (accountInfo.battleTag or accountInfo.accountName)) or gameAccountName or tostring(bnetAccountID),
    battleTag = accountInfo and accountInfo.battleTag or nil,
    accountName = accountInfo and accountInfo.accountName or nil,
    bnetAccountID = bnetAccountID,
    gameAccountName = gameAccountName,
    guid = gameAccountInfo and gameAccountInfo.playerGuid or nil,
  }
end

function Identity.BuildConversationKey(localProfileId, contactKey)
  return localProfileId .. "::" .. contactKey
end

ns.Identity = Identity

return Identity
