local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local IgnoreList = ns.IgnoreList or require("WhisperMessenger.Model.Filters.IgnoreList")
local KeywordRules = ns.KeywordRules or require("WhisperMessenger.Model.Filters.KeywordRules")
local PerfCounters = ns.PerfCounters or require("WhisperMessenger.Util.PerfCounters")
local SecretString = ns.GroupChatIngestSecretString or require("WhisperMessenger.Core.Ingest.GroupChatIngest.SecretString")

-- Decides whether an incoming line reaches the store: ignore list first (every
-- kind), then keyword rules (group and channel lines only). Several chat
-- frames see the same line, so each decision is cached by lineID in a fixed
-- ring and its counters move once. Per line, the ignore lookup builds one
-- name-realm key while the ignore list is non-empty, and rule matching makes
-- one lowercased copy of the text while a rule is enabled. Nothing else
-- allocates.
local IncomingFilter = {}

local PASS = "pass"
local IGNORED = "ignored"
local BLOCKED = "blocked"
local RING_SIZE = 64

local lower = string.lower
local next = next
local ipairs = ipairs

local ringIds = {}
local ringDecisions = {}
for slot = 1, RING_SIZE do
  ringIds[slot] = false
  ringDecisions[slot] = false
end
local cursor = 0

-- Only real chat lineIDs are cached; 0 or a missing ID would share a slot.
local function isCacheable(lineID)
  return type(lineID) == "number" and lineID > 0
end

function IncomingFilter.DecisionFor(lineID)
  if not isCacheable(lineID) then
    return nil
  end
  for slot = 1, RING_SIZE do
    if ringIds[slot] == lineID then
      return ringDecisions[slot]
    end
  end
  return nil
end

local function remember(lineID, decision)
  if not isCacheable(lineID) then
    return
  end
  cursor = cursor % RING_SIZE + 1
  ringIds[cursor] = lineID
  ringDecisions[cursor] = decision
end

local function hasEnabledRule(rules)
  for _, rule in ipairs(rules) do
    if rule.enabled then
      return true
    end
  end
  return false
end

local function decide(runtime, kind, playerName, text, channelLabel)
  local filters = runtime and runtime.accountState and runtime.accountState.filters
  if type(filters) ~= "table" then
    return PASS
  end
  local now = type(runtime.now) == "function" and runtime.now() or 0

  -- An empty list skips the name lookup (Ambiguate + lower) entirely.
  if type(filters.ignored) == "table" and next(filters.ignored) ~= nil then
    local entry = IgnoreList.Lookup(filters, playerName, now)
    if entry ~= nil then
      IgnoreList.RecordBlocked(entry, text, channelLabel, now)
      PerfCounters.Increment("ignored")
      return IGNORED
    end
  end

  if kind == "whisper" or type(filters.rules) ~= "table" or not hasEnabledRule(filters.rules) then
    return PASS
  end
  local rule = KeywordRules.Match(filters, lower(text))
  if rule ~= nil then
    rule.blocked = (rule.blocked or 0) + 1
    PerfCounters.Increment("ruleBlocked")
    return BLOCKED
  end
  return PASS
end

-- kind: "whisper", "group" or "channel". isSelf: the caller found the line is
-- the player's own (Direction.IsLocalSender); own lines always pass.
-- Returns "pass", "ignored" or "blocked".
function IncomingFilter.Evaluate(runtime, kind, playerName, text, lineID, channelLabel, isSelf)
  if isSelf or type(playerName) ~= "string" or type(text) ~= "string" then
    return PASS
  end
  if SecretString.IsSecretString(playerName) or SecretString.IsSecretString(text) then
    return PASS
  end
  local cached = IncomingFilter.DecisionFor(lineID)
  if cached ~= nil then
    return cached
  end
  local decision = decide(runtime, kind, playerName, text, channelLabel)
  remember(lineID, decision)
  return decision
end

ns.IncomingFilter = IncomingFilter
return IncomingFilter
