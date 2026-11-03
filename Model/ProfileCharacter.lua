local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- The WoW character a contact stands for, for profile links: { name, realm,
-- displayRealm }. Chat names carry the realm without spaces ("Area52"), or
-- none for the player's own realm. Only the own realm's display name
-- ("Argent Dawn") is known, unless the realm already has a space.
local ProfileCharacter = {}

-- ownRealm: { display = GetRealmName(), normalized = GetNormalizedRealmName() }.
function ProfileCharacter.OwnRealm()
  local function call(fn)
    if type(fn) ~= "function" then
      return nil
    end
    local ok, value = pcall(fn)
    if not ok or SecretValue.Is(value) or type(value) ~= "string" or value == "" then
      return nil
    end
    return value
  end
  return { display = call(_G.GetRealmName), normalized = call(_G.GetNormalizedRealmName) }
end

local function fullName(item)
  if item.channel == "WOW" then
    return item.displayName, true
  end
  if item.channel ~= "BN" then
    return nil, false
  end
  if type(item.characterName) == "string" and type(item.realm) == "string" and item.realm ~= "" then
    return item.characterName .. "-" .. item.realm, false
  end
  -- A friend's character without a realm could be on any realm.
  return item.gameAccountName, false
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

local function displayRealmFor(realm, ownRealm)
  if string.find(realm, " ", 1, true) then
    return realm
  end
  if realm == ownRealm.normalized then
    return ownRealm.display
  end
  return nil
end

function ProfileCharacter.FromItem(item, ownRealm)
  if type(item) ~= "table" then
    return nil
  end
  local name, mayOmitRealm = fullName(item)
  -- A chat-lockdown secret string raises on any comparison or string call.
  if SecretValue.Is(name) or type(name) ~= "string" or name == "" then
    return nil
  end
  local character, realm = split(name)
  if character == nil then
    return nil
  end
  if realm == nil then
    if not mayOmitRealm then
      return nil
    end
    realm = ownRealm.normalized
    if realm == nil then
      return nil
    end
  end
  return { name = character, realm = realm, displayRealm = displayRealmFor(realm, ownRealm) }
end

ns.ProfileCharacter = ProfileCharacter
return ProfileCharacter
