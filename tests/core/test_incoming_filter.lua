local IncomingFilter = require("WhisperMessenger.Core.Ingest.IncomingFilter")
local IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList")
local KeywordRules = require("WhisperMessenger.Model.Filters.KeywordRules")
local PerfCounters = require("WhisperMessenger.Util.PerfCounters")

local function makeRuntime()
  local filters = { ignored = {}, rules = {} }
  return {
    accountState = { filters = filters },
    now = function()
      return 500
    end,
  }, filters
end

return function()
  -- test_ignored_sender_is_dropped_and_recorded
  do
    PerfCounters.Reset()
    local runtime, filters = makeRuntime()
    local entry = assert(IgnoreList.Add(filters, "Spammer", { now = 1 }))
    local decision = IncomingFilter.Evaluate(runtime, "channel", "Spammer", "cheap gold", 101, "Trade")
    assert(decision == "ignored", "ignored sender gives ignored, got " .. tostring(decision))
    assert(entry.blocked == 1, "entry counts the blocked line")
    assert(entry.lastText == "cheap gold" and entry.lastChannel == "Trade" and entry.lastAt == 500, "entry keeps the latest blocked line")
    assert(PerfCounters.Get("ignored") == 1, "ignored counter increments")
  end

  -- test_ignore_applies_to_whispers
  do
    local runtime, filters = makeRuntime()
    IgnoreList.Add(filters, "Spammer", { now = 1 })
    assert(IncomingFilter.Evaluate(runtime, "whisper", "Spammer", "hi", 102, "WHISPER") == "ignored", "whispers honour the ignore list")
  end

  -- test_rule_match_blocks_group_lines
  do
    PerfCounters.Reset()
    local runtime, filters = makeRuntime()
    local rule = assert(KeywordRules.Add(filters, "wts boost"))
    assert(IncomingFilter.Evaluate(runtime, "group", "Seller", "WTS mythic BOOST", 103, "GUILD") == "blocked", "rule match blocks")
    assert(rule.blocked == 1, "rule counts the blocked line")
    assert(PerfCounters.Get("ruleBlocked") == 1, "ruleBlocked counter increments")
  end

  -- test_rules_do_not_apply_to_whispers
  do
    local runtime, filters = makeRuntime()
    KeywordRules.Add(filters, "wts boost")
    assert(IncomingFilter.Evaluate(runtime, "whisper", "Seller", "wts boost", 104, "WHISPER") == "pass", "rules skip whispers")
  end

  -- test_clean_line_passes
  do
    local runtime, filters = makeRuntime()
    KeywordRules.Add(filters, "wts boost")
    assert(IncomingFilter.Evaluate(runtime, "channel", "Friend", "lfm heroic", 105, "Trade") == "pass", "clean line passes")
  end

  -- test_same_line_id_counts_once (Review Focus 5)
  do
    PerfCounters.Reset()
    local runtime, filters = makeRuntime()
    local entry = assert(IgnoreList.Add(filters, "Spammer", { now = 1 }))
    assert(IncomingFilter.Evaluate(runtime, "channel", "Spammer", "spam", 42, "Trade") == "ignored")
    assert(IncomingFilter.Evaluate(runtime, "channel", "Spammer", "spam", 42, "Trade") == "ignored", "cached decision is returned")
    assert(entry.blocked == 1, "a line seen by several chat frames counts once, got " .. entry.blocked)
    assert(PerfCounters.Get("ignored") == 1, "counter increments once")
    assert(IncomingFilter.DecisionFor(42) == "ignored", "decision is readable from the cache")
  end

  -- test_ring_evicts_oldest_line_after_64
  do
    local runtime, filters = makeRuntime()
    local entry = assert(IgnoreList.Add(filters, "Spammer", { now = 1 }))
    for lineID = 1001, 1065 do
      IncomingFilter.Evaluate(runtime, "channel", "Spammer", "spam", lineID, "Trade")
    end
    assert(entry.blocked == 65, "every distinct line counts")
    assert(IncomingFilter.DecisionFor(1001) == nil, "the 65th line evicted the first")
    IncomingFilter.Evaluate(runtime, "channel", "Spammer", "spam", 1001, "Trade")
    assert(entry.blocked == 66, "an evicted line is recomputed")
  end

  -- test_non_string_values_pass
  do
    local runtime, filters = makeRuntime()
    IgnoreList.Add(filters, "Spammer", { now = 1 })
    assert(IncomingFilter.Evaluate(runtime, "channel", nil, "spam", 106, "Trade") == "pass", "nil sender passes")
    assert(IncomingFilter.Evaluate(runtime, "channel", "Spammer", nil, 107, "Trade") == "pass", "nil text passes")
  end

  -- test_missing_filters_pass
  do
    assert(IncomingFilter.Evaluate({ accountState = {} }, "channel", "Spammer", "spam", 108, "Trade") == "pass", "no filters state passes")
  end
end
