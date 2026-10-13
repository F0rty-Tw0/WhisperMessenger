local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SeenLevel = ns.SeenLevel or require("WhisperMessenger.Model.SeenLevel")

-- The zone the last /who showed for a player, by name key.
-- Memory only: a zone is a snapshot, and the next sighting refreshes it.
local SeenZone = {}

SeenZone.MAX_ENTRIES = 5000

local byName = {}
local entryCount = 0

-- A failed check counts as secret: a 12.0 secret zone must never be stored.
local function isSecret(value)
  local issecretvalue = _G.issecretvalue
  if type(issecretvalue) ~= "function" then
    return false
  end
  local ok, secret = pcall(issecretvalue, value)

  return not ok or secret == true
end

local function isValidZone(zone)
  return not isSecret(zone) and type(zone) == "string" and zone ~= ""
end

local function clear()
  for key in pairs(byName) do
    byName[key] = nil
  end
  entryCount = 0
end

-- grug: wipe-all cap; LRU if it ever matters
local function reserve(key)
  if byName[key] ~= nil then
    return
  end
  if entryCount + 1 > SeenZone.MAX_ENTRIES then
    clear()
  end
  entryCount = entryCount + 1
end

function SeenZone.Record(name, zone, seenAt)
  if not isValidZone(zone) then
    return false
  end
  local key = SeenLevel.NameKey(name)
  if key == nil then
    return false
  end
  reserve(key)
  byName[key] = { zone = zone, seenAt = seenAt }

  return true
end

function SeenZone.Get(name)
  local key = SeenLevel.NameKey(name)
  local entry = key ~= nil and byName[key] or nil
  if entry == nil then
    return nil, nil
  end

  return entry.zone, entry.seenAt
end

function SeenZone._reset()
  clear()
end

ns.SeenZone = SeenZone

return SeenZone
