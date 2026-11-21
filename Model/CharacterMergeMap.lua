local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Account-wide saved maps for character chats folded into a Battle.net chat.
-- merged[characterKey] = { bnetKey = ..., name = ... }; separated[characterKey]
-- = true once the player split that character off for good.
local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")

local CharacterMergeMap = {}

local ipairs = ipairs
local pairs = pairs
local sort = table.sort

function CharacterMergeMap.Ensure(accountState)
  if type(accountState.mergedCharacters) ~= "table" then
    accountState.mergedCharacters = {}
  end
  if type(accountState.separatedCharacters) ~= "table" then
    accountState.separatedCharacters = {}
  end
  return { merged = accountState.mergedCharacters, separated = accountState.separatedCharacters }
end

-- Saved data is a trust boundary: a malformed entry reads as unmerged.
function CharacterMergeMap.Get(merges, characterKey)
  local entry = merges.merged[characterKey]
  if type(entry) ~= "table" or type(entry.bnetKey) ~= "string" then
    return nil
  end
  -- Every line of a merged character is stamped with this name.
  if type(entry.name) ~= "string" or entry.name == "" then
    return nil
  end

  return entry
end

function CharacterMergeMap.Record(merges, characterKey, bnetKey, name)
  merges.merged[characterKey] = { bnetKey = bnetKey, name = name }
end

function CharacterMergeMap.Drop(merges, characterKey)
  merges.merged[characterKey] = nil
end

function CharacterMergeMap.MarkSeparated(merges, characterKey)
  merges.merged[characterKey] = nil
  merges.separated[characterKey] = true
end

function CharacterMergeMap.IsSeparated(merges, characterKey)
  return merges.separated[characterKey] == true
end

-- Collected before the caller mutates, so changing entries is safe under pairs.
local function keysFor(merges, bnetKey)
  local keys = {}
  for characterKey in pairs(merges.merged) do
    local entry = CharacterMergeMap.Get(merges, characterKey)
    if entry ~= nil and entry.bnetKey == bnetKey then
      keys[#keys + 1] = characterKey
    end
  end
  return keys
end

function CharacterMergeMap.ClearForBnet(merges, bnetKey)
  for _, characterKey in ipairs(keysFor(merges, bnetKey)) do
    merges.merged[characterKey] = nil
  end
end

function CharacterMergeMap.RewriteBnetKey(merges, oldKey, newKey)
  for _, characterKey in ipairs(keysFor(merges, oldKey)) do
    merges.merged[characterKey].bnetKey = newKey
  end
end

-- Saved data may hold a non-string key, so both tie-break sides go through tostring.
local function byNameThenKey(a, b)
  local nameA, nameB = tostring(a.name), tostring(b.name)
  if nameA ~= nameB then
    return nameA < nameB
  end
  return tostring(a.characterKey) < tostring(b.characterKey)
end

function CharacterMergeMap.ListForBnet(merges, bnetKey)
  local list = {}
  for _, characterKey in ipairs(keysFor(merges, bnetKey)) do
    list[#list + 1] = { characterKey = characterKey, name = merges.merged[characterKey].name }
  end
  sort(list, byNameThenKey)
  return list
end

-- The Battle.net chat a character key was merged into while that chat is
-- stored, else nil. It only reads: an entry whose chat is gone stays in the
-- map until the next whisper from the character drops it.
function CharacterMergeMap.LiveBnetKey(merges, conversations, characterKey)
  if type(merges) ~= "table" or type(conversations) ~= "table" or characterKey == nil then
    return nil
  end
  local entry = CharacterMergeMap.Get(merges, characterKey)
  if entry == nil or conversations[entry.bnetKey] == nil then
    return nil
  end

  return entry.bnetKey
end

local CHARACTER_KEY_PREFIX = "wow::WOW::"

-- The name part of a character key, without the realm, or nil for any other key.
local function baseNameOf(key)
  if type(key) ~= "string" or string.find(key, CHARACTER_KEY_PREFIX, 1, true) ~= 1 then
    return nil
  end

  return string.match(string.sub(key, #CHARACTER_KEY_PREFIX + 1), "^([^%-]+)")
end

-- A name without a realm finds a merged character on any realm, as the name
-- lookup does, but only when no other merged character or character chat
-- shares that name.
local function mergedKeyForBareName(merges, conversations, baseName)
  local found = nil
  for characterKey in pairs(merges.merged) do
    if baseNameOf(characterKey) == baseName and CharacterMergeMap.Get(merges, characterKey) ~= nil then
      if found ~= nil then
        return nil
      end
      found = characterKey
    end
  end
  if found == nil then
    return nil
  end
  for key in pairs(conversations) do
    if key ~= found and baseNameOf(key) == baseName then
      return nil
    end
  end

  return found
end

-- The merged Battle.net chat key plus the character key it was built from.
local function mergedChatForName(merges, conversations, name)
  if type(merges) ~= "table" or type(conversations) ~= "table" then
    return nil
  end
  local contact = Identity.FromWhisper(name)
  if contact.canonicalName == "" then
    return nil
  end
  -- A character key never holds the local profile id.
  local characterKey = Identity.BuildConversationKey(nil, contact.contactKey)
  local hasRealm = string.find(contact.canonicalName, "-", 1, true) ~= nil
  if CharacterMergeMap.Get(merges, characterKey) == nil and not hasRealm then
    characterKey = mergedKeyForBareName(merges, conversations, contact.canonicalName)
  end
  local bnetKey = CharacterMergeMap.LiveBnetKey(merges, conversations, characterKey)
  if bnetKey == nil then
    return nil
  end

  return bnetKey, characterKey
end

-- The Battle.net chat a character name was merged into, or nil. It only
-- reads: an entry whose Battle.net chat is gone stays in the map.
function CharacterMergeMap.BnetKeyForName(merges, conversations, name)
  local bnetKey = mergedChatForName(merges, conversations, name)

  return bnetKey
end

-- The chat a character name resolves to: its own chat while one is stored,
-- else the Battle.net chat it was merged into, else the name lookup. The
-- merge wins over the lookup's bare-name fallback, which could pick a
-- same-named character on another realm.
function CharacterMergeMap.ResolveWhisperName(runtime, name)
  local conversations = runtime and runtime.store and runtime.store.conversations
  local bnetKey, characterKey = mergedChatForName(runtime and runtime.characterMerges, conversations, name)
  if bnetKey ~= nil and conversations[characterKey] == nil then
    return bnetKey
  end

  return Identity.ResolveWhisperConversation(runtime, name, "WOW")
end

ns.CharacterMergeMap = CharacterMergeMap
return CharacterMergeMap
