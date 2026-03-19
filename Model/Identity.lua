local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = {}

local function normalizeName(name)
  return string.lower(name or "")
end

local ALLIANCE_RACES = {
  Human = true,
  Dwarf = true,
  NightElf = true,
  Gnome = true,
  Draenei = true,
  Worgen = true,
  VoidElf = true,
  LightforgedDraenei = true,
  DarkIronDwarf = true,
  KulTiran = true,
  Mechagnome = true,
}

local HORDE_RACES = {
  Orc = true,
  Scourge = true,
  Tauren = true,
  Troll = true,
  BloodElf = true,
  Goblin = true,
  Nightborne = true,
  HighmountainTauren = true,
  MagharOrc = true,
  ZandalariTroll = true,
  Vulpera = true,
}

local function inferFactionName(raceTag)
  if ALLIANCE_RACES[raceTag] then
    return "Alliance"
  end

  if HORDE_RACES[raceTag] then
    return "Horde"
  end

  -- Pandaren, Dracthyr, Earthen, and unknown future neutral races are ambiguous here.
  return nil
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
    factionName = playerInfo.factionName or inferFactionName(playerInfo.raceTag),
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
    className = gameAccountInfo and gameAccountInfo.className or nil,
    raceName = gameAccountInfo and gameAccountInfo.raceName or nil,
    factionName = gameAccountInfo and gameAccountInfo.factionName or nil,
  }
end

function Identity.BuildConversationKey(localProfileId, contactKey)
  return localProfileId .. "::" .. contactKey
end

ns.Identity = Identity

return Identity
