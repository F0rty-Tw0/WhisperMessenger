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
  local entry = {
    name = name,
    reason = opts.reason,
    addedAt = now,
    expiresAt = opts.duration and now and (now + opts.duration) or nil,
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

ns.IgnoreList = IgnoreList
return IgnoreList
