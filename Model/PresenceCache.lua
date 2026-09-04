local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PresenceCache = {}

-- A full guild/community enumeration allocates one info table per member, so
-- a large guild costs megabytes of garbage per pass. Cap unattended rescans.
local INDEX_MIN_INTERVAL = 300

-- Private module state
local cache = {}
-- guid -> club/member coordinates, kept as two flat maps so the index costs
-- two tables instead of one table per member.
local indexClub = {}
local indexMember = {}
-- guid -> current zone name, kept alongside the presence cache.
local zoneByGuid = {}
-- guid -> timestamp of the last presence read for that GUID.
local freshAt = {}
local indexBuiltAt = nil
local lastRebuiltAt = 0
local ttl = 30
local dirty = true
local clubApi = nil
local function normalizeNow(now)
  if type(now) ~= "number" then
    return 0
  end
  return math.floor(now)
end

local function defaultNow()
  local timeFn = _G.time
  if type(timeFn) ~= "function" then
    return 0
  end
  return normalizeNow(timeFn())
end

local nowFn = defaultNow
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
    return ipairs({})
  end
  return iter, state, start
end

-- info.zone can be a secret value under 12.0 restricted content: the ~=
-- comparison itself can throw, so the whole validation (not just the field
-- read) must run under pcall in the caller.
local function readZone(info)
  local zone = info.zone
  if type(zone) == "string" and zone ~= "" then
    return zone
  end
  return nil
end

-- In 12.0 restricted content (e.g. Mythic+), info's fields can be "secret
-- values" — any ==/~= comparison or table-key use throws. Record one member
-- via pcall so a throw on this member (secret guid as table key, or secret
-- presence) skips it instead of aborting the whole club scan.
local function recordMember(acc, clubId, memberId, info)
  acc.club[info.guid] = clubId
  acc.member[info.guid] = memberId
  acc.freshAt[info.guid] = acc.now
  local p = presenceToString(info.presence)
  if p then
    acc.cache[info.guid] = p
  end
  -- recordMember already runs under pcall (see cacheClub), so a throw from
  -- readZone on a secret zone just aborts this member like any other field.
  local zone = readZone(info)
  if zone then
    acc.zoneByGuid[info.guid] = zone
  end
end

local function cacheClub(acc, api, clubId)
  local ok, members = pcall(api.GetClubMembers, clubId)
  if not ok or type(members) ~= "table" then
    return
  end
  for _, memberId in safeIpairs(members) do
    local infoOk, info = pcall(api.GetMemberInfo, clubId, memberId)
    if infoOk and info then
      pcall(recordMember, acc, clubId, memberId, info)
    end
  end
end

function PresenceCache.Initialize(api, options)
  options = options or {}
  clubApi = api
  ttl = options.ttl or 30
  local providedNow = options.now
  if type(providedNow) == "function" then
    nowFn = function()
      return normalizeNow(providedNow())
    end
  else
    nowFn = defaultNow
  end
  cache = {}
  indexClub = {}
  indexMember = {}
  zoneByGuid = {}
  freshAt = {}
  indexBuiltAt = nil
  lastRebuiltAt = 0
  -- Don't rebuild immediately — club data may not be loaded yet at ADDON_LOADED time.
  -- Mark dirty so the first timer tick or event triggers the rebuild when data is ready.
  dirty = true
end

function PresenceCache.Rebuild()
  local now = nowFn()
  local acc = { cache = {}, club = {}, member = {}, zoneByGuid = {}, freshAt = {}, now = now }

  if type(clubApi) == "table" then
    local guildId = nil

    -- Cache guild members
    if type(clubApi.GetGuildClubId) == "function" then
      local ok, id = pcall(clubApi.GetGuildClubId)
      if ok and id then
        guildId = id
        cacheClub(acc, clubApi, id)
      end
    end

    -- Cache all community members. The guild club is also listed here, so
    -- skip it rather than enumerating every guild member a second time.
    if type(clubApi.GetSubscribedClubs) == "function" then
      local ok, clubs = pcall(clubApi.GetSubscribedClubs)
      if ok and clubs then
        for _, club in ipairs(clubs) do
          if club.clubId ~= guildId then
            cacheClub(acc, clubApi, club.clubId)
          end
        end
      end
    end
  end

  cache = acc.cache
  indexClub = acc.club
  indexMember = acc.member
  zoneByGuid = acc.zoneByGuid
  freshAt = acc.freshAt
  indexBuiltAt = now
  lastRebuiltAt = now
  dirty = false
end

function PresenceCache.GetPresence(guid)
  if guid == nil then
    return nil
  end
  return cache[guid]
end

function PresenceCache.GetZone(guid)
  if guid == nil then
    return nil
  end
  return zoneByGuid[guid]
end

-- Comparing a secret value (12.0 restricted content, e.g. Mythic+) throws, so
-- this runs under pcall in the caller.
local function guidMatches(info, guid)
  return info.guid == guid
end

-- Read one member straight from the index: a single API call, no enumeration.
-- Returns presence (may be nil for an unknown presence enum) plus whether the
-- GUID was actually resolved.
local function lookupIndexed(guid)
  local clubId = indexClub[guid]
  if clubId == nil or type(clubApi) ~= "table" then
    return nil, false
  end

  local ok, info = pcall(clubApi.GetMemberInfo, clubId, indexMember[guid])
  if not ok or type(info) ~= "table" then
    -- Member IDs shift when people leave a club; drop the stale coordinates
    -- rather than reporting somebody else's presence under this GUID.
    indexClub[guid] = nil
    indexMember[guid] = nil
    return nil, false
  end

  local matchOk, matches = pcall(guidMatches, info, guid)
  if not matchOk then
    -- info.guid is a secret value under 12.0 restricted content: unreadable
    -- right now, but the club/member coordinates are still valid. Keep the
    -- index and report the last known presence instead of erroring out.
    return cache[guid], true
  end
  if not matches then
    indexClub[guid] = nil
    indexMember[guid] = nil
    return nil, false
  end

  local zoneOk, zone = pcall(readZone, info)
  if zoneOk and zone then
    zoneByGuid[guid] = zone
  end

  local presenceOk, presence = pcall(presenceToString, info.presence)
  if not presenceOk then
    -- Same secret-value case, this time on the presence field.
    return cache[guid], true
  end

  return presence, true
end

-- Targeted single-GUID refresh: one member lookup against the index built by
-- Rebuild. Falls back to a full rescan only when the index has never been
-- built, or when club membership changed and the rescan interval has elapsed.
function PresenceCache.RefreshPresence(guid)
  if guid == nil or type(clubApi) ~= "table" then
    return nil
  end

  local presence, found = lookupIndexed(guid)
  if not found then
    local staleIndex = dirty and indexBuiltAt ~= nil and (nowFn() - indexBuiltAt) >= INDEX_MIN_INTERVAL
    if indexBuiltAt == nil or staleIndex then
      PresenceCache.Rebuild()
      presence = lookupIndexed(guid)
    end
  end

  cache[guid] = presence
  freshAt[guid] = nowFn()
  return presence
end

-- Refresh this GUID only if its last read is older than the TTL. Callers that
-- run on every window refresh should use this instead of RefreshPresence.
function PresenceCache.EnsureFresh(guid)
  if guid == nil or type(clubApi) ~= "table" then
    return nil
  end

  local readAt = freshAt[guid]
  if readAt ~= nil and (nowFn() - readAt) < ttl then
    return cache[guid]
  end

  return PresenceCache.RefreshPresence(guid)
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
  indexClub = {}
  indexMember = {}
  zoneByGuid = {}
  freshAt = {}
  indexBuiltAt = nil
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
