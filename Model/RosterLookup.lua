local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")

-- Finds a guild or community member's GUID by character name. Used when a
-- whisper fails and the game never sent the target's GUID.
-- ponytail: full roster scan per call; fine for rare failed sends, index it
-- in PresenceCache.Rebuild if a hot path ever needs it.
local RosterLookup = {}

local function canonical(name)
  return Identity.FromWhisper(name).canonicalName
end

-- Member fields can be 12.0 secret values, so this runs under pcall.
local function matchingGUID(info, target)
  if canonical(info.name) == target then
    return info.guid
  end
  return nil
end

local function findInClub(api, clubId, target)
  local ok, members = pcall(api.GetClubMembers, clubId)
  if not ok or type(members) ~= "table" then
    return nil
  end
  for _, memberId in ipairs(members) do
    local infoOk, info = pcall(api.GetMemberInfo, clubId, memberId)
    if infoOk and type(info) == "table" then
      local matchOk, guid = pcall(matchingGUID, info, target)
      if matchOk and guid then
        return guid
      end
    end
  end
  return nil
end

-- The subscribed clubs include the guild.
function RosterLookup.FindGUIDByName(api, name)
  if type(api) ~= "table" or type(api.GetSubscribedClubs) ~= "function" or name == nil then
    return nil
  end
  local ok, clubs = pcall(api.GetSubscribedClubs)
  if not ok or type(clubs) ~= "table" then
    return nil
  end
  local target = canonical(name)
  for _, club in ipairs(clubs) do
    local guid = findInClub(api, club.clubId, target)
    if guid then
      return guid
    end
  end
  return nil
end

ns.RosterLookup = RosterLookup
return RosterLookup
