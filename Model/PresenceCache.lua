local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PresenceCache = {}

-- Private module state
local cache = {}
local lastRebuiltAt = 0
local ttl = 30
local dirty = true
local clubApi = nil
local nowFn = nil

local function presenceToString(presence)
  if presence == 1 or presence == 2 or presence == 4 then
    return "online"
  end
  if presence == 3 then
    return "offline"
  end
  return nil
end

local function safeIpairs(tbl)
  local iterOk, iter, state, start = pcall(ipairs, tbl)
  if not iterOk then
    return function()
      return nil
    end
  end
  return iter, state, start
end

local function cacheClub(newCache, api, clubId)
  local ok, members = pcall(api.GetClubMembers, clubId)
  if not ok or type(members) ~= "table" then
    return
  end
  for _, memberId in safeIpairs(members) do
    local infoOk, info = pcall(api.GetMemberInfo, clubId, memberId)
    if infoOk and info and info.guid then
      local p = presenceToString(info.presence)
      if p then
        newCache[info.guid] = p
      end
    end
  end
end

function PresenceCache.Initialize(api, options)
  options = options or {}
  clubApi = api
  ttl = options.ttl or 30
  nowFn = options.now or function()
    return type(_G.time) == "function" and _G.time() or 0
  end
  cache = {}
  lastRebuiltAt = 0
  -- Don't rebuild immediately — club data may not be loaded yet at ADDON_LOADED time.
  -- Mark dirty so the first timer tick or event triggers the rebuild when data is ready.
  dirty = true
end

function PresenceCache.Rebuild()
  local newCache = {}

  if type(clubApi) == "table" then
    -- Cache guild members
    if type(clubApi.GetGuildClubId) == "function" then
      local ok, guildId = pcall(clubApi.GetGuildClubId)
      if ok and guildId then
        cacheClub(newCache, clubApi, guildId)
      end
    end

    -- Cache all community members
    if type(clubApi.GetSubscribedClubs) == "function" then
      local ok, clubs = pcall(clubApi.GetSubscribedClubs)
      if ok and clubs then
        for _, club in ipairs(clubs) do
          cacheClub(newCache, clubApi, club.clubId)
        end
      end
    end
  end

  cache = newCache
  lastRebuiltAt = nowFn()
  dirty = false
end

function PresenceCache.GetPresence(guid)
  if guid == nil then
    return nil
  end
  return cache[guid]
end

-- Targeted single-GUID refresh: scans guild + communities for just this GUID
-- and updates the cache entry. Only ~3-5 API calls, not a full rebuild.
-- Use on contact click to get fresh presence without rebuilding everything.
function PresenceCache.RefreshPresence(guid)
  if guid == nil or type(clubApi) ~= "table" then
    return nil
  end

  local function findInClub(clubId)
    local ok, members = pcall(clubApi.GetClubMembers, clubId)
    if not ok or type(members) ~= "table" then
      return nil
    end
    for _, memberId in safeIpairs(members) do
      local infoOk, info = pcall(clubApi.GetMemberInfo, clubId, memberId)
      if infoOk and info and info.guid == guid then
        return presenceToString(info.presence)
      end
    end
    return nil
  end

  -- Check guild
  if type(clubApi.GetGuildClubId) == "function" then
    local ok, guildId = pcall(clubApi.GetGuildClubId)
    if ok and guildId then
      local presence = findInClub(guildId)
      if presence then
        cache[guid] = presence
        return presence
      end
    end
  end

  -- Check communities
  if type(clubApi.GetSubscribedClubs) == "function" then
    local ok, clubs = pcall(clubApi.GetSubscribedClubs)
    if ok and clubs then
      for _, club in ipairs(clubs) do
        local presence = findInClub(club.clubId)
        if presence then
          cache[guid] = presence
          return presence
        end
      end
    end
  end

  -- Not found in any club — remove from cache if stale
  cache[guid] = nil
  return nil
end

function PresenceCache.Invalidate()
  dirty = true
end

function PresenceCache.IsStale()
  if dirty then
    return true
  end
  return (nowFn() - lastRebuiltAt) >= ttl
end

function PresenceCache.SetTTL(seconds)
  ttl = seconds
end

function PresenceCache.GetTTL()
  return ttl
end

-- Test helpers (prefixed with _ to indicate internal use)
function PresenceCache._reset()
  cache = {}
  lastRebuiltAt = 0
  dirty = true
  clubApi = nil
  nowFn = function()
    return 0
  end
end

-- Test helper: Initialize + Rebuild (in production, Rebuild is deferred)
function PresenceCache._initForTest(api, options)
  PresenceCache.Initialize(api, options)
  PresenceCache.Rebuild()
end

function PresenceCache._setCache(tbl)
  cache = tbl or {}
  dirty = false
  lastRebuiltAt = nowFn and nowFn() or 0
end

ns.PresenceCache = PresenceCache

return PresenceCache
