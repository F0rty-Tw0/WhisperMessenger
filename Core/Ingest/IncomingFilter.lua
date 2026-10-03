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
-- ring and its counters move once. Nothing here allocates per line beyond
-- lowercasing the text once.
local IncomingFilter = {}

local PASS = "pass"
local IGNORED = "ignored"
local BLOCKED = "blocked"
local RING_SIZE = 64

local lower = string.lower
local next = next

local ringIds = {}
local ringDecisions = {}
for slot = 1, RING_SIZE do
  ringIds[slot] = false
  ringDecisions[slot] = false
end
local cursor = 0

function IncomingFilter.DecisionFor(lineID)
  if lineID == nil then
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
  if lineID == nil then
    return
  end
  cursor = cursor % RING_SIZE + 1
  ringIds[cursor] = lineID
  ringDecisions[cursor] = decision
end

local function decide(runtime, kind, playerName, text, channelLabel)
  local filters = runtime and runtime.accountState and runtime.accountState.filters
  if type(filters) ~= "table" then
    return PASS
  end
  local now = type(runtime.now) == "function" and runtime.now() or 0

  if type(filters.ignored) == "table" then
    local entry = IgnoreList.Lookup(filters, playerName, now)
    if entry ~= nil then
      IgnoreList.RecordBlocked(entry, text, channelLabel, now)
      PerfCounters.Increment("ignored")
      return IGNORED
    end
  end

  if kind == "whisper" or type(filters.rules) ~= "table" or next(filters.rules) == nil then
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
