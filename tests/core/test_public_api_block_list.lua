local IgnoreList = require("WhisperMessenger.Model.Filters.IgnoreList")
local PublicApi = require("WhisperMessenger.Core.PublicApi")

local KEY = "bob-area52"

local function makeRuntime(visible, now)
  local runtime = { accountState = {}, syncs = 0, refreshes = 0 }
  runtime.now = function()
    return now or 1000
  end
  runtime.isWindowVisible = function()
    return visible
  end
  runtime.syncChatFilters = function()
    runtime.syncs = runtime.syncs + 1
  end
  runtime.refreshWindow = function()
    runtime.refreshes = runtime.refreshes + 1
  end
  return runtime
end

local function ignored(runtime)
  return IgnoreList.Ensure(runtime.accountState).ignored
end

return function()
  local savedRealm = rawget(_G, "GetNormalizedRealmName")
  rawset(_G, "GetNormalizedRealmName", function()
    return "Area52"
  end)

  -- test_is_blocked_false_for_unlisted_player
  do
    local api = PublicApi.Build(makeRuntime(true))
    assert(api.IsBlocked("Bob") == false, "an unlisted player is not blocked")
  end

  -- test_block_adds_permanent_entry_without_reason
  do
    local runtime = makeRuntime(true)
    local api = PublicApi.Build(runtime)
    assert(api.Block("Bob") == true, "Block returns true once blocked")
    local entry = runtime.accountState.filters.ignored[KEY]
    assert(entry ~= nil, "entry stored under the realm key")
    assert(entry.expiresAt == nil, "new entry is permanent")
    assert(entry.reason == nil, "new entry has no reason")
  end

  -- test_is_blocked_true_after_block_for_both_name_forms
  do
    local api = PublicApi.Build(makeRuntime(true))
    assert(api.Block("Bob") == true)
    assert(api.IsBlocked("Bob") == true, "bare name reads as blocked")
    assert(api.IsBlocked("BOB-Area52") == true, "full name reads as blocked")
  end

  -- test_block_keeps_existing_reason_and_expiry
  do
    local runtime = makeRuntime(true)
    ignored(runtime)[KEY] = { name = "Bob-Area52", reason = "spam", expiresAt = 5000, blocked = 2 }
    local api = PublicApi.Build(runtime)
    assert(api.Block("Bob") == true, "a live entry counts as blocked")
    local entry = ignored(runtime)[KEY]
    assert(entry.reason == "spam", "reason kept")
    assert(entry.expiresAt == 5000, "expiry kept")
    assert(entry.blocked == 2, "blocked count kept")
    assert(runtime.syncs == 0, "no change, no sync")
  end

  -- test_expired_entry_reads_as_not_blocked_and_is_dropped
  do
    local runtime = makeRuntime(true, 1000)
    ignored(runtime)[KEY] = { name = "Bob-Area52", expiresAt = 500 }
    local api = PublicApi.Build(runtime)
    assert(api.IsBlocked("Bob") == false, "an expired entry is not blocked")
    assert(ignored(runtime)[KEY] == nil, "the expired entry is dropped")
  end

  -- test_block_replaces_expired_entry_with_permanent_one
  do
    local runtime = makeRuntime(true, 1000)
    ignored(runtime)[KEY] = { name = "Bob-Area52", expiresAt = 500 }
    local api = PublicApi.Build(runtime)
    assert(api.Block("Bob") == true)
    assert(ignored(runtime)[KEY] ~= nil, "fresh entry stored")
    assert(ignored(runtime)[KEY].expiresAt == nil, "fresh entry is permanent")
  end

  -- test_unblock_removes_entry
  do
    local api = PublicApi.Build(makeRuntime(true))
    assert(api.Block("Bob") == true)
    assert(api.Unblock("Bob") == true, "Unblock returns true")
    assert(api.IsBlocked("Bob") == false, "player no longer blocked")
  end

  -- test_unblock_of_unlisted_player_is_true_and_still_syncs
  do
    local runtime = makeRuntime(true)
    local api = PublicApi.Build(runtime)
    assert(api.Unblock("Bob") == true, "not blocked after the call")
    assert(runtime.syncs == 1, "valid Unblock always syncs, got " .. runtime.syncs)
  end

  -- test_bad_names_return_false_and_store_nothing
  do
    local runtime = makeRuntime(true)
    local api = PublicApi.Build(runtime)
    local BAD = { nil, 42, {}, "", "   " }
    for i = 1, 5 do
      assert(api.IsBlocked(BAD[i]) == false, "IsBlocked bad name " .. i)
      assert(api.Block(BAD[i]) == false, "Block bad name " .. i)
      assert(api.Unblock(BAD[i]) == false, "Unblock bad name " .. i)
    end
    assert(next(ignored(runtime)) == nil, "no key stored for a bad name")
    assert(runtime.syncs == 0, "bad names never sync")
  end

  -- test_secret_name_returns_false_before_any_string_op
  do
    local savedSecret = rawget(_G, "issecretvalue")
    local savedFind, savedLower, savedGsub = string.find, string.lower, string.gsub
    local touched = false
    local function guard(original)
      return function(first, ...)
        if first == "Secret" then
          touched = true
          error("string op on a secret")
        end
        return original(first, ...)
      end
    end
    rawset(_G, "issecretvalue", function(value)
      return value == "Secret"
    end)
    rawset(string, "find", guard(savedFind))
    rawset(string, "lower", guard(savedLower))
    rawset(string, "gsub", guard(savedGsub))

    local runtime = makeRuntime(true)
    local api = PublicApi.Build(runtime)
    local results = { api.IsBlocked("Secret"), api.Block("Secret"), api.Unblock("Secret") }

    rawset(string, "find", savedFind)
    rawset(string, "lower", savedLower)
    rawset(string, "gsub", savedGsub)
    rawset(_G, "issecretvalue", savedSecret)

    assert(results[1] == false and results[2] == false and results[3] == false, "secret name returns false")
    assert(touched == false, "no string function touched the secret")
    assert(next(ignored(runtime)) == nil, "nothing stored for a secret")
    assert(runtime.syncs == 0, "a secret never syncs")
  end

  -- test_change_syncs_and_refreshes_a_visible_window
  do
    local runtime = makeRuntime(true)
    local api = PublicApi.Build(runtime)
    assert(api.Block("Bob") == true)
    assert(runtime.syncs == 1, "synced once, got " .. runtime.syncs)
    assert(runtime.refreshes == 1, "refreshed once, got " .. runtime.refreshes)
  end

  -- test_hidden_window_syncs_but_is_not_refreshed
  do
    local runtime = makeRuntime(false)
    local api = PublicApi.Build(runtime)
    assert(api.Block("Bob") == true)
    assert(runtime.syncs == 1, "synced once, got " .. runtime.syncs)
    assert(runtime.refreshes == 0, "hidden window not refreshed, got " .. runtime.refreshes)
  end

  -- test_is_blocked_never_syncs_or_refreshes
  do
    local runtime = makeRuntime(true)
    local api = PublicApi.Build(runtime)
    assert(api.Block("Bob") == true)
    local syncs, refreshes = runtime.syncs, runtime.refreshes
    assert(api.IsBlocked("Bob") == true)
    assert(runtime.syncs == syncs, "IsBlocked does not sync")
    assert(runtime.refreshes == refreshes, "IsBlocked does not refresh")
  end

  -- test_internal_error_returns_false
  do
    local runtime = makeRuntime(true)
    runtime.syncChatFilters = function()
      error("boom")
    end
    local api = PublicApi.Build(runtime)
    assert(api.Block("Bob") == false, "an internal error is false and does not raise")
  end

  rawset(_G, "GetNormalizedRealmName", savedRealm)
end
