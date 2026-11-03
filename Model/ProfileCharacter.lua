local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- The WoW character a contact stands for, for profile links: { name, realm,
-- displayRealm }. Chat names carry the realm without spaces ("Area52"), or
-- none for the player's own realm; only the own realm's display name
-- ("Argent Dawn") is known. A Battle.net friend's character is read live
-- from Battle.net, which gives the display name.
local ProfileCharacter = {}

local function isText(value)
  return not SecretValue.Is(value) and type(value) == "string" and value ~= ""
end

local function anySecret(...)
  for index = 1, select("#", ...) do
    if SecretValue.Is((select(index, ...))) then
      return true
    end
  end
  return false
end

-- ownRealm: { display = GetRealmName(), normalized = GetNormalizedRealmName() }.
function ProfileCharacter.OwnRealm()
  local function call(fn)
    if type(fn) ~= "function" then
      return nil
    end
    local ok, value = pcall(fn)
    return ok and isText(value) and value or nil
  end
  return { display = call(_G.GetRealmName), normalized = call(_G.GetNormalizedRealmName) }
end

-- game: { regionId, projectId }. The character the friend plays right now,
-- or nil when they are not in WoW on this game version and region: a stored
-- character may be one they logged off from, or on another version.
local function liveFriendCharacter(item, game)
  local BNetResolver = ns.BNetResolver or require("WhisperMessenger.Transport.BNetResolver")
  local accountInfo = BNetResolver.ResolveAccountInfo(_G.C_BattleNet, item.bnetAccountID, item.guid, item.battleTag or item.displayName)
  local info = type(accountInfo) == "table" and accountInfo.gameAccountInfo or nil
  if type(info) ~= "table" then
    return nil
  end
  local name, realm = info.characterName, info.realmName
  if anySecret(info.isOnline, info.clientProgram, info.wowProjectID, info.regionID) or not isText(name) or not isText(realm) then
    return nil
  end
  local inThisGame = info.isOnline == true
    and info.clientProgram == (_G.BNET_CLIENT_WOW or "WoW")
    and info.wowProjectID == game.projectId
    and info.regionID == game.regionId
  if not inThisGame then
    return nil
  end
  return { name = name, realm = (string.gsub(realm, " ", "")), displayRealm = realm }
end

local function split(name)
  if string.find(name, "|", 1, true) then
    return nil, nil
  end
  local character, realm = string.match(name, "^([^%-]+)%-?(.*)$")
  if character == nil then
    return nil, nil
  end
  return character, realm ~= "" and realm or nil
end

-- ownRealm: as OwnRealm returns. game: { regionId, projectId }.
function ProfileCharacter.FromItem(item, ownRealm, game)
  if type(item) ~= "table" then
    return nil
  end
  if item.channel == "BN" then
    local known = type(game) == "table" and game.projectId ~= nil and game.regionId ~= nil
    return known and liveFriendCharacter(item, game) or nil
  end
  if item.channel ~= "WOW" then
    return nil
  end
  -- A chat-lockdown secret string raises on any comparison or string call.
  local name = item.displayName
  if not isText(name) then
    return nil
  end
  local character, realm = split(name)
  if character == nil then
    return nil
  end
  realm = realm or ownRealm.normalized
  if realm == nil then
    return nil
  end
  local displayRealm = realm == ownRealm.normalized and ownRealm.display or nil
  return { name = character, realm = realm, displayRealm = displayRealm }
end

ns.ProfileCharacter = ProfileCharacter
return ProfileCharacter
