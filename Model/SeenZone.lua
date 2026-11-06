local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SeenByName = ns.SeenByName or require("WhisperMessenger.Model.SeenByName")

-- The zone the last /who showed for a player, by name key.
-- Memory only: a zone is a snapshot, and the next sighting refreshes it.
local SeenZone = {}

SeenZone.MAX_ENTRIES = 5000

local store = SeenByName.New(SeenZone)

local function isValidZone(zone)
  return not SeenByName.IsSecret(zone) and type(zone) == "string" and zone ~= ""
end

function SeenZone.Record(name, zone, seenAt)
  if not isValidZone(zone) then
    return false
  end

  return store.Put(name, { zone = zone, seenAt = seenAt })
end

function SeenZone.Get(name)
  local entry = store.Get(name)
  if entry == nil then
    return nil, nil
  end

  return entry.zone, entry.seenAt
end

function SeenZone._reset()
  store.Reset()
end

ns.SeenZone = SeenZone

return SeenZone
