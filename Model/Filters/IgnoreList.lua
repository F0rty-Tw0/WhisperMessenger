local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Identity = ns.Identity or require("WhisperMessenger.Model.Identity")
local TextLimits = ns.TextLimits or require("WhisperMessenger.Util.TextLimits")

-- Account-wide silent ignore: a listed player's lines are dropped at ingest.
-- Expiry is lazy (checked on lookup, plus a sweep at login); no timers.
local IgnoreList = {}

local lower = string.lower
local pairs = pairs

-- Lowercased short name, or nil for non-strings and secret values
-- (string.lower throws on a secret string).
function IgnoreList.Key(name)
  if type(name) ~= "string" then
    return nil
  end
  local ok, key = pcall(lower, Identity.ShortName(name))
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

-- opts.duration: seconds until expiry, nil for forever.
function IgnoreList.Add(filters, name, opts)
  local key = IgnoreList.Key(name)
  if key == nil then
    return nil
  end
  opts = opts or {}
  local entry = {
    name = name,
    reason = opts.reason,
    addedAt = opts.now,
    expiresAt = opts.duration and opts.now and (opts.now + opts.duration) or nil,
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
