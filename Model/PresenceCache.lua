local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local MemberRecord = ns.PresenceCacheMemberRecord or require("WhisperMessenger.Model.PresenceCache.MemberRecord")

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
-- guid -> last known character level. Never cleared when the member goes offline.
local levelByGuid = {}
-- guid -> timestamp of the last presence read for that GUID.
local freshAt = {}
local indexBuiltAt = nil
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
  levelByGuid = {}
  freshAt = {}
  indexBuiltAt = nil
  -- Don't rebuild immediately — club data may not be loaded yet at ADDON_LOADED time.
  -- Mark dirty so the first timer tick or event triggers the rebuild when data is ready.
  dirty = true
end

function PresenceCache.Rebuild()
  local now = nowFn()
  local acc = { cache = {}, club = {}, member = {}, zoneByGuid = {}, levelByGuid = {}, freshAt = {}, now = now }

  if type(clubApi) == "table" then
    local guildId = nil

    -- Cache guild members
    if type(clubApi.GetGuildClubId) == "function" then
      local ok, id = pcall(clubApi.GetGuildClubId)
      if ok and id then
        guildId = id
        MemberRecord.CacheClub(acc, clubApi, id)
      end
    end

    -- Cache all community members. The guild club is also listed here, so
    -- skip it rather than enumerating every guild member a second time.
    if type(clubApi.GetSubscribedClubs) == "function" then
      local ok, clubs = pcall(clubApi.GetSubscribedClubs)
      if ok and clubs then
        for _, club in ipairs(clubs) do
          if club.clubId ~= guildId then
            MemberRecord.CacheClub(acc, clubApi, club.clubId)
          end
        end
      end
    end
  end

  cache = acc.cache
  indexClub = acc.club
  indexMember = acc.member
  zoneByGuid = acc.zoneByGuid
  levelByGuid = acc.levelByGuid
  freshAt = acc.freshAt
  indexBuiltAt = now
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

function PresenceCache.GetLevel(guid)
  if guid == nil then
    return nil
  end
  return levelByGuid[guid]
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

  local zoneOk, zone = pcall(MemberRecord.ReadZone, info)
  if zoneOk and zone then
    zoneByGuid[guid] = zone
  end

  -- Before the presence read: a secret presence returns early below.
  local levelOk, level = pcall(MemberRecord.ReadLevel, info)
  if levelOk and level then
    levelByGuid[guid] = level
  end

  local presenceOk, presence = pcall(MemberRecord.ReadPresence, info)
  if not presenceOk then
    -- Same secret-value case, this time on the presence field.
    return cache[guid], true
  end

  return presence, true
end

-- Live level for a GUID already in the club index: one member read, never a
-- rescan, so a stranger costs a table lookup. Presence cache stays untouched.
function PresenceCache.ReadLevel(guid)
  if guid == nil then
    return nil
  end
  lookupIndexed(guid)
  return levelByGuid[guid]
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

-- Test helpers (prefixed with _ to indicate internal use)
function PresenceCache._reset()
  cache = {}
  indexClub = {}
  indexMember = {}
  zoneByGuid = {}
  levelByGuid = {}
  freshAt = {}
  indexBuiltAt = nil
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
end

ns.PresenceCache = PresenceCache

return PresenceCache
