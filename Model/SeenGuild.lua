local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SeenByName = ns.SeenByName or require("WhisperMessenger.Model.SeenByName")

-- The guild name last seen for a player, by name key. "" means seen with no guild.
-- Memory only: a guild is a snapshot, and the next sighting refreshes it.
local SeenGuild = {}

SeenGuild.MAX_ENTRIES = 5000

local store = SeenByName.New(SeenGuild)

function SeenGuild.Record(name, guildName)
  if SeenByName.IsSecret(guildName) or type(guildName) ~= "string" then
    return false
  end

  return store.Put(name, guildName)
end

function SeenGuild.Get(name)
  return store.Get(name)
end

function SeenGuild._reset()
  store.Reset()
end

ns.SeenGuild = SeenGuild

return SeenGuild
