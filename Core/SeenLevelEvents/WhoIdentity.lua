local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Factions = ns.IdentityFactions or require("WhisperMessenger.Model.Identity.Factions")
local RaceTags = ns.IdentityRaceTags or require("WhisperMessenger.Model.Identity.RaceTags")
local WhoRow = ns.WhoRow or require("WhisperMessenger.Core.WhoRow")
local SecretValue = ns.SecretValue or require("WhisperMessenger.Util.SecretValue")

-- Writes a /who row's class, race and faction onto the matching whisper chat.
-- A /who answer is the freshest source, so it overwrites what the chat had.
local WhoIdentity = {}

local function usable(value)
  return not SecretValue.Is(value) and type(value) == "string" and value ~= ""
end

local function setField(conversation, field, value)
  if conversation[field] == value then
    return false
  end
  conversation[field] = value
  return true
end

-- An unmapped race still shows; its tag and faction are cleared only when the
-- race itself changed, so no faction of another race stays behind. A chat
-- with a guid keeps them: on gendered locales /who may spell the same race
-- another way than the guid lookup did.
local function applyRace(conversation, raceName)
  local raceTag = RaceTags.FromName(raceName)
  if raceTag == nil then
    if not setField(conversation, "raceName", raceName) then
      return false
    end
    if conversation.guid ~= nil then
      return true
    end
    conversation.raceTag = nil
    conversation.factionName = nil
    return true
  end
  local changed = setField(conversation, "raceName", raceName)
  changed = setField(conversation, "raceTag", raceTag) or changed
  -- Neutral races (Pandaren, ...) have no faction: keep the stored one.
  local faction = Factions.InferFaction(raceTag)
  if faction ~= nil then
    changed = setField(conversation, "factionName", faction) or changed
  end
  return changed
end

-- Runs under pcall. findChat(name) returns key, conversation for a saved WoW
-- whisper chat. Each field is checked on its own: a secret or empty one never
-- blocks the others. Returns the chat's key when anything changed.
function WhoIdentity.RecordWhoRow(info, systemText, findChat)
  if systemText ~= nil and not WhoRow.Matches(systemText, info) then
    return nil
  end
  local key, conversation = findChat(info.fullName)
  if conversation == nil then
    return nil
  end
  local changed = false
  if usable(info.classStr) then
    changed = setField(conversation, "className", info.classStr) or changed
  end
  if usable(info.filename) then
    changed = setField(conversation, "classTag", info.filename) or changed
  end
  if usable(info.raceStr) then
    changed = applyRace(conversation, info.raceStr) or changed
  end
  if changed then
    return key
  end
  return nil
end

ns.SeenLevelEventsWhoIdentity = WhoIdentity
return WhoIdentity
