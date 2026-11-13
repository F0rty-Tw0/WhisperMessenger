local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local CommunityIndex = {}

-- guid -> clubId of the first non-guild club listing that member.
local byGuid = {}
-- Bumped on every Rebuild and never reset, so a cache keyed on it can't see a
-- generation number twice.
local generation = 0

function CommunityIndex.Swap(map)
  byGuid = map or {}
  generation = generation + 1
end

function CommunityIndex.Clear()
  byGuid = {}
end

function CommunityIndex.Get(guid)
  if guid == nil then
    return nil
  end
  return byGuid[guid]
end

function CommunityIndex.Generation()
  return generation
end

ns.PresenceCacheCommunityIndex = CommunityIndex

return CommunityIndex
