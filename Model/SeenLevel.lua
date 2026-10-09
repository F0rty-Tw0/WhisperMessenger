local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")

-- Levels the game has shown the player this session, by GUID and by name.
-- Memory only: a level is a snapshot, and the next sighting refreshes it.
local SeenLevel = {}

SeenLevel.MAX_ENTRIES = 5000

local byGuid = {}
local byName = {}
local entryCount = 0

-- Runs under pcall: comparing a 12.0 secret value throws.
local function isValidLevel(level)
  return type(level) == "number" and level > 0
end

local function lowerShortName(name)
  return string.lower(Identity.ShortName(name))
end

-- Same rule as a conversation's canonical name: the realm drops only for
-- same-realm players, so two realms' namesakes stay separate.
function SeenLevel.NameKey(name)
  if name == nil then
    return nil
  end
  local ok, key = pcall(lowerShortName, name)
  if ok then
    return key
  end
  return nil
end

-- Cleared in place: store() holds a reference to one of these tables.
local function clear(tbl)
  for key in pairs(tbl) do
    tbl[key] = nil
  end
end

local function isNewKey(tbl, key)
  return key ~= nil and tbl[key] == nil
end

local function countNewKeys(guid, nameKey)
  local count = 0
  if isNewKey(byGuid, guid) then
    count = count + 1
  end
  if isNewKey(byName, nameKey) then
    count = count + 1
  end
  return count
end

-- grug: wipe-all cap; LRU if it ever matters
-- Wipes before either write, so both entries of this call survive it.
local function reserve(guid, nameKey)
  local added = countNewKeys(guid, nameKey)
  if entryCount + added > SeenLevel.MAX_ENTRIES then
    clear(byGuid)
    clear(byName)
    entryCount = 0
    added = countNewKeys(guid, nameKey)
  end
  entryCount = entryCount + added
end

local function store(tbl, key, level)
  if key == nil or tbl[key] == level then
    return false
  end
  tbl[key] = level
  return true
end

function SeenLevel.Record(guid, name, level)
  local ok, valid = pcall(isValidLevel, level)
  if not ok or not valid then
    return false
  end
  local nameKey = SeenLevel.NameKey(name)
  reserve(guid, nameKey)
  local guidChanged = store(byGuid, guid, level)
  local nameChanged = store(byName, nameKey, level)
  return guidChanged or nameChanged
end

function SeenLevel.Get(guid, name)
  local level = guid ~= nil and byGuid[guid] or nil
  if level ~= nil then
    return level
  end
  local key = SeenLevel.NameKey(name)
  if key == nil then
    return nil
  end
  return byName[key]
end

function SeenLevel._reset()
  clear(byGuid)
  clear(byName)
  entryCount = 0
end

ns.SeenLevel = SeenLevel

return SeenLevel
