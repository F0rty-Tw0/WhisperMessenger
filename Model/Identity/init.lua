local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Factions = ns.IdentityFactions or require("WhisperMessenger.Model.Identity.Factions")

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

function Identity.InferFaction(raceTag)
  return Factions.InferFaction(raceTag)
end

function Identity.BuildLocalProfileId(name, realmName)
  if name == nil or name == "" then
    return nil
  end

  if realmName ~= nil and realmName ~= "" then
    return normalizeName(name .. "-" .. realmName)
  end

  return normalizeName(name)
end

function Identity.FromWhisper(fullName, guid, playerInfo)
  playerInfo = playerInfo or {}
  return {
    channel = "WOW",
    contactKey = "WOW::" .. normalizeName(fullName),
    canonicalName = normalizeName(fullName),
    displayName = fullName,
    guid = guid,
    className = playerInfo.className,
    classTag = playerInfo.classTag,
    raceName = playerInfo.raceName,
    raceTag = playerInfo.raceTag,
    factionName = playerInfo.factionName or Factions.InferFaction(playerInfo.raceTag),
  }
end

function Identity.FromBattleNet(bnetAccountID, accountInfo)
  local gameAccountName = buildGameAccountName(accountInfo)
  local gameAccountInfo = accountInfo and accountInfo.gameAccountInfo or nil

  return {
    channel = "BN",
    contactKey = "BN::" .. tostring(bnetAccountID),
    canonicalName = tostring(bnetAccountID),
    displayName = (accountInfo and (accountInfo.battleTag or accountInfo.accountName)) or gameAccountName or tostring(
      bnetAccountID
    ),
    battleTag = accountInfo and accountInfo.battleTag or nil,
    accountName = accountInfo and accountInfo.accountName or nil,
    bnetAccountID = bnetAccountID,
    gameAccountName = gameAccountName,
    guid = gameAccountInfo and gameAccountInfo.playerGuid or nil,
    className = gameAccountInfo and gameAccountInfo.className or nil,
    raceName = gameAccountInfo and gameAccountInfo.raceName or nil,
    factionName = gameAccountInfo and gameAccountInfo.factionName or nil,
  }
end

function Identity.BuildConversationKey(localProfileId, contactKey)
  -- BNet conversations are account-wide, use a shared prefix
  if type(contactKey) == "string" and string.find(contactKey, "BN::", 1, true) == 1 then
    return "bnet::" .. contactKey
  end
  -- WoW whisper conversations are account-wide, use a shared prefix
  if type(contactKey) == "string" and string.find(contactKey, "WOW::", 1, true) == 1 then
    return "wow::" .. contactKey
  end
  return localProfileId .. "::" .. contactKey
end

ns.Identity = Identity

return Identity
