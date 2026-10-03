local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

-- Account-wide silent ignore: a listed player's lines are dropped at ingest.
-- Expiry is lazy (checked on lookup, plus a sweep at login); no timers.
local IgnoreList = {}

local find = string.find
local gsub = string.gsub
local lower = string.lower
local pairs = pairs

local function localRealm()
  if type(_G.GetNormalizedRealmName) ~= "function" then
    return nil
  end
  local ok, realm = pcall(_G.GetNormalizedRealmName)
  if ok and type(realm) == "string" and realm ~= "" then
    return realm
  end
  return nil
end

-- The list is account-wide, so a bare same-realm name gets the local realm:
-- "Bob" on Area52 and "Bob-Area52" anywhere are the same player. Falls back
-- to the bare name when the realm is unknown.
local function fullName(name)
  name = Identity.ShortName(name)
  if not find(name, "-", 1, true) then
    local realm = localRealm()
    if realm ~= nil then
      name = name .. "-" .. realm
    end
  end
  return (gsub(lower(name), "%s", ""))
end

-- "Bob" -> "Bob-Area52" when the local realm is known, so the list shows
-- which player it means; full names are kept as typed.
local function withRealm(name)
  if find(name, "-", 1, true) then
    return name
  end
  local realm = localRealm()
  return realm and (name .. "-" .. realm) or name
end

-- Lowercased "name-realm", or nil for non-strings and secret values
-- (string operations throw on a secret string).
function IgnoreList.Key(name)
  if type(name) ~= "string" then
    return nil
  end
  local ok, key = pcall(fullName, name)
  if not ok or type(key) ~= "string" then
    return nil
  end
  return key
end

-- "Name-Realm" of the character behind guid when the client knows it, so a
-- saved realm-less name can't be taken for a player on the current realm.
-- Falls back to name.
function IgnoreList.CharacterName(name, guid)
  if type(guid) ~= "string" or type(_G.GetPlayerInfoByGUID) ~= "function" then
    return name
  end
  local ok, _, _, _, _, _, guidName, realm = pcall(_G.GetPlayerInfoByGUID, guid)
  if not ok or type(guidName) ~= "string" or guidName == "" then
    return name
  end
  if type(realm) == "string" and realm ~= "" then
    return guidName .. "-" .. gsub(realm, "%s", "")
  end
  return guidName
end

function IgnoreList.Ensure(accountState)
  local filters = accountState.filters
  if type(filters) ~= "table" then
    filters = {}
    accountState.filters = filters
  end
  if type(filters.ignored) ~= "table" then
    filters.ignored = {}
  end
  if type(filters.rules) ~= "table" then
    filters.rules = {}
  end
  return filters
end

-- opts.duration: seconds until expiry, nil for forever. opts.now defaults
-- to the clock.
function IgnoreList.Add(filters, name, opts)
  local key = IgnoreList.Key(name)
  if key == nil then
    return nil
  end
  opts = opts or {}
  local now = opts.now
  if now == nil and type(_G.time) == "function" then
    now = _G.time()
  end
  local expiresAt = opts.duration and now and (now + opts.duration) or nil
  -- Re-adding a player updates the reason and expiry but keeps what the
  -- entry has blocked so far.
  local existing = filters.ignored[key]
  if existing ~= nil then
    existing.reason = opts.reason
    existing.expiresAt = expiresAt
    return existing
  end
  local entry = {
    name = withRealm(name),
    reason = opts.reason,
    addedAt = now,
    expiresAt = expiresAt,
    blocked = 0,
  }
  filters.ignored[key] = entry
  return entry
end

function IgnoreList.Remove(filters, name)
  local key = IgnoreList.Key(name)
  if key ~= nil then
    filters.ignored[key] = nil
  end
end

-- Removes the entry stored under `key` as is: the list may hold keys made on
-- another realm, which Key(name) would rebuild differently here.
function IgnoreList.RemoveKey(filters, key)
  filters.ignored[key] = nil
end

local function isExpired(entry, now)
  return entry.expiresAt ~= nil and now ~= nil and entry.expiresAt <= now
end

function IgnoreList.Lookup(filters, name, now)
  local key = IgnoreList.Key(name)
  if key == nil then
    return nil
  end
  local entry = filters.ignored[key]
  if entry == nil then
    return nil
  end
  if isExpired(entry, now) then
    filters.ignored[key] = nil
    return nil
  end
  return entry
end

function IgnoreList.RecordBlocked(entry, text, channelLabel, now)
  entry.blocked = (entry.blocked or 0) + 1
  if type(text) == "string" then
    entry.lastText = TextLimits.CapBytes(text, TextLimits.MESSAGE_MAX_BYTES)
  end
  entry.lastChannel = channelLabel
  entry.lastAt = now
end

function IgnoreList.Sweep(filters, now)
  for key, entry in pairs(filters.ignored) do
    if isExpired(entry, now) then
      filters.ignored[key] = nil
    end
  end
end

-- Blocked counts cover one session: the login zeroes what the last one saved.
function IgnoreList.ClearBlockedCounts(filters)
  for _, entry in pairs(filters.ignored) do
    if type(entry) == "table" then
      entry.blocked = 0
    end
  end
  for _, rule in ipairs(filters.rules) do
    if type(rule) == "table" then
      rule.blocked = 0
    end
  end
end

ns.IgnoreList = IgnoreList
return IgnoreList
