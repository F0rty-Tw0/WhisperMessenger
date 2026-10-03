local IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList")

local function newFilters()
  return { ignored = {}, rules = {} }
end

return function()
  -- test_add_then_lookup_returns_entry_with_reason
  do
    local filters = newFilters()
    IgnoreList.Add(filters, "Spammer-Realm", { reason = "gold seller", now = 100 })
    local entry = IgnoreList.Lookup(filters, "Spammer-Realm", 200)
    assert(entry ~= nil, "added name is found")
    assert(entry.reason == "gold seller", "entry keeps its reason")
    assert(entry.name == "Spammer-Realm", "entry keeps the typed name")
    assert(entry.addedAt == 100, "entry records when it was added")
    assert(entry.expiresAt == nil, "no duration means forever")
    assert(entry.blocked == 0, "a new entry has blocked nothing")
  end

  -- test_lookup_is_case_insensitive
  do
    local filters = newFilters()
    IgnoreList.Add(filters, "Spammer-Realm", { now = 1 })
    assert(IgnoreList.Lookup(filters, "spammer-realm", 2) ~= nil, "lowercase lookup finds the entry")
    assert(IgnoreList.Key("SPAMMER-Realm") == "spammer-realm", "key is lowercased")
  end

  -- test_key_is_nil_for_non_strings
  do
    assert(IgnoreList.Key(nil) == nil, "nil name has no key")
    assert(IgnoreList.Key(42) == nil, "number name has no key")
    assert(IgnoreList.Lookup(newFilters(), nil, 1) == nil, "lookup of nil name is nil")
  end

  -- test_expired_entry_passes_and_is_removed (Review Focus 4)
  do
    local filters = newFilters()
    IgnoreList.Add(filters, "Spammer", { now = 1000, duration = 86400 })
    assert(filters.ignored["spammer"].expiresAt == 1000 + 86400, "expiry is now + duration")
    assert(IgnoreList.Lookup(filters, "Spammer", 1000 + 86401) == nil, "expired entry no longer ignores")
    assert(filters.ignored["spammer"] == nil, "expired entry is deleted on lookup")
  end

  -- test_remove_deletes_entry
  do
    local filters = newFilters()
    IgnoreList.Add(filters, "Spammer", { now = 1 })
    IgnoreList.Remove(filters, "SPAMMER")
    assert(filters.ignored["spammer"] == nil, "remove is case-insensitive")
  end

  -- test_record_blocked_caps_last_text
  do
    local filters = newFilters()
    local entry = assert(IgnoreList.Add(filters, "Spammer", { now = 1 }))
    IgnoreList.RecordBlocked(entry, string.rep("a", 400), "Trade", 50)
    assert(entry.blocked == 1, "blocked counter increments")
    assert(#entry.lastText <= 255, "last text is capped at 255 bytes, got " .. #entry.lastText)
    assert(entry.lastChannel == "Trade", "last channel is stored")
    assert(entry.lastAt == 50, "last time is stored")
  end

  -- test_sweep_removes_only_expired_entries
  do
    local filters = newFilters()
    IgnoreList.Add(filters, "Old", { now = 0, duration = 86400 })
    IgnoreList.Add(filters, "Week", { now = 0, duration = 604800 })
    IgnoreList.Add(filters, "Forever", { now = 0 })
    IgnoreList.Sweep(filters, 100000)
    assert(filters.ignored["old"] == nil, "expired entry is swept")
    assert(filters.ignored["week"] ~= nil, "unexpired entry stays")
    assert(filters.ignored["forever"] ~= nil, "forever entry stays")
  end

  -- test_ensure_backfills_filters_for_old_saved_variables
  do
    local accountState = { conversations = {} }
    local filters = IgnoreList.Ensure(accountState)
    assert(accountState.filters == filters, "filters are stored on the account")
    assert(type(filters.ignored) == "table" and type(filters.rules) == "table", "both lists exist")
    local kept = { ignored = { x = {} } }
    accountState.filters = kept
    assert(IgnoreList.Ensure(accountState) == kept and type(kept.rules) == "table", "existing filters are kept and completed")
  end
end
