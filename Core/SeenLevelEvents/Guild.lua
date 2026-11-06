local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local SeenGuild = ns.SeenGuild or require("WhisperMessenger.Model.SeenGuild")
local WhoRow = ns.WhoRow or require("WhisperMessenger.Core.WhoRow")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- Feeds SeenGuild from the sightings SeenLevelEvents already captures.
local Guild = {}

-- Runs under pcall: any system line inside the who window lands here; only
-- the reply's own row counts. An empty guild is a real answer: no guild.
function Guild.RecordWhoRow(info, systemText)
  if systemText ~= nil and not WhoRow.Matches(systemText, info) then
    return
  end
  SeenGuild.Record(info.fullName, info.fullGuildName)
end

-- Runs under pcall: a secret or failing read must not cost the level record.
-- A nil guild is not stored: the client returns nil until guild info loads,
-- so it cannot mean "no guild".
function Guild.RecordUnit(name, unit)
  local ok, guildName = pcall(_G.GetGuildInfo, unit)
  if not ok then
    return
  end
  if SecretValue.Is(guildName) or type(guildName) ~= "string" or guildName == "" then
    return
  end
  SeenGuild.Record(name, guildName)
end

ns.SeenLevelEventsGuild = Guild
return Guild
