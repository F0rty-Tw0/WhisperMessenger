local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Account-wide saved maps for character chats folded into a Battle.net chat.
-- merged[characterKey] = { bnetKey = ..., name = ... }; separated[characterKey]
-- = true once the player split that character off for good.
local CharacterMergeMap = {}

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

function CharacterMergeMap.ClearForBnet(merges, bnetKey)
  for characterKey in pairs(merges.merged) do
    local entry = CharacterMergeMap.Get(merges, characterKey)
    if entry ~= nil and entry.bnetKey == bnetKey then
      merges.merged[characterKey] = nil
    end
  end
end

function CharacterMergeMap.RewriteBnetKey(merges, oldKey, newKey)
  for characterKey in pairs(merges.merged) do
    local entry = CharacterMergeMap.Get(merges, characterKey)
    if entry ~= nil and entry.bnetKey == oldKey then
      entry.bnetKey = newKey
    end
  end
end

local function byNameThenKey(a, b)
  local nameA, nameB = tostring(a.name), tostring(b.name)
  if nameA ~= nameB then
    return nameA < nameB
  end
  return a.characterKey < b.characterKey
end

function CharacterMergeMap.ListForBnet(merges, bnetKey)
  local list = {}
  for characterKey in pairs(merges.merged) do
    local entry = CharacterMergeMap.Get(merges, characterKey)
    if entry ~= nil and entry.bnetKey == bnetKey then
      list[#list + 1] = { characterKey = characterKey, name = entry.name }
    end
  end
  sort(list, byNameThenKey)
  return list
end

ns.CharacterMergeMap = CharacterMergeMap
return CharacterMergeMap
