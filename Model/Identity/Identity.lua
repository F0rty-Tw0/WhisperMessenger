local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Factions = ns.IdentityFactions or require("WhisperMessenger.Model.Identity.Factions")

local Identity = {}

local function normalizeName(name)
  if name == nil then
    return ""
  end
  -- Detaint secret strings from chat events before string ops.
  -- During tainted execution (e.g. mythic lockdown) Ambiguate itself
  -- rejects secret values, so guard with pcall.
  if _G.Ambiguate then
    local ok, clean = pcall(_G.Ambiguate, name, "none")
    if ok then
      name = clean
    end
  end
  local ok, result = pcall(string.lower, name)
  if ok then
    return result
  end
  return ""
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
  -- Detaint the name once; normalizeName handles nil but displayName needs a clean copy too.
  -- pcall guards against tainted execution (mythic lockdown).
  if _G.Ambiguate and fullName then
    local ok, clean = pcall(_G.Ambiguate, fullName, "none")
    if ok then
      fullName = clean
    end
  end
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

function Identity.FromBattleNet(bnetAccountID, accountInfo, playerInfo)
  local gameAccountName = buildGameAccountName(accountInfo)
  local gameAccountInfo = accountInfo and accountInfo.gameAccountInfo or nil
  playerInfo = playerInfo or {}

  local stableKey = (accountInfo and accountInfo.battleTag) or tostring(bnetAccountID)
  return {
    channel = "BN",
    contactKey = "BN::" .. normalizeName(stableKey),
    canonicalName = normalizeName(stableKey),
    displayName = (accountInfo and (accountInfo.battleTag or accountInfo.accountName)) or gameAccountName or tostring(
      bnetAccountID
    ),
    battleTag = accountInfo and accountInfo.battleTag or nil,
    accountName = accountInfo and accountInfo.accountName or nil,
    bnetAccountID = bnetAccountID,
    gameAccountName = gameAccountName,
    guid = gameAccountInfo and gameAccountInfo.playerGuid or nil,
    className = playerInfo.className or (gameAccountInfo and gameAccountInfo.className or nil),
    classTag = playerInfo.classTag or nil,
    raceName = playerInfo.raceName or (gameAccountInfo and gameAccountInfo.raceName or nil),
    raceTag = playerInfo.raceTag or nil,
    factionName = (gameAccountInfo and gameAccountInfo.factionName)
      or (playerInfo.factionName or Factions.InferFaction(playerInfo.raceTag))
      or nil,
  }
end

function Identity.BuildConversationKey(localProfileId, contactKey)
  if type(contactKey) ~= "string" then
    return localProfileId .. "::" .. tostring(contactKey)
  end

  -- BNet conversations are account-wide, use a shared prefix
  if string.find(contactKey, "BN::", 1, true) == 1 then
    return "bnet::" .. contactKey
  end
  -- WoW whisper conversations are per-character key, use a shared prefix
  if string.find(contactKey, "WOW::", 1, true) == 1 then
    return "wow::" .. contactKey
  end

  -- BN Conversation: account-wide; key includes the conversation id
  -- contactKey shape: "BNCONV::<id>"
  if string.find(contactKey, "BNCONV::", 1, true) == 1 then
    local id = string.sub(contactKey, 9) -- strip "BNCONV::"
    return "bnconv::" .. id
  end

  -- Community: account-wide; both clubId and streamId are stable
  -- contactKey shape: "COMMUNITY::<clubId>::<streamId>"
  if string.find(contactKey, "COMMUNITY::", 1, true) == 1 then
    local rest = string.sub(contactKey, 12) -- strip "COMMUNITY::"
    return "community::" .. rest
  end

  -- Guild: account-wide when the ingesting caller supplies a guild name
  -- (shape "GUILD::<guildName>"). Characters in the same guild share the
  -- same conversation. Without a name we fall back to the per-character
  -- key so legacy/bare ingest paths still work.
  if string.find(contactKey, "GUILD::", 1, true) == 1 then
    local name = string.sub(contactKey, 8) -- strip "GUILD::"
    if type(name) == "string" and name ~= "" then
      local ok, lowered = pcall(string.lower, name)
      if ok and type(lowered) == "string" and lowered ~= "" then
        return "guild::" .. lowered
      end
    end
    return "guild::" .. localProfileId
  end
  if string.find(contactKey, "OFFICER::", 1, true) == 1 then
    return "officer::" .. localProfileId
  end
  if string.find(contactKey, "PARTY::", 1, true) == 1 then
    return "party::" .. localProfileId
  end
  if string.find(contactKey, "RAID::", 1, true) == 1 then
    return "raid::" .. localProfileId
  end
  if string.find(contactKey, "INSTANCE::", 1, true) == 1 then
    return "instance::" .. localProfileId
  end

  -- Channel: per-character; key includes the channel basename
  -- contactKey shape: "CHANNEL::<basename>"
  if string.find(contactKey, "CHANNEL::", 1, true) == 1 then
    local basename = string.sub(contactKey, 10) -- strip "CHANNEL::"
    return "channel::" .. localProfileId .. "::" .. basename
  end

  -- Unknown/ambiguous contactKey: fall back to localProfileId::contactKey
  return localProfileId .. "::" .. contactKey
end

ns.Identity = Identity

return Identity
