local FriendList = require("tests.helpers.bnet_friend_list")
local BNetResolver = require("WhisperMessenger.Transport.BNetResolver")

-- ResolveAccountInfo with a pass cache: one friend-list walk for a whole
-- pass, and the same answers as the uncached lookup.

local buildApi = FriendList.NewApi
local accountInfo = FriendList.AccountInfo

-- The fields the callers read, as one comparable string.
local function summary(info)
  if info == nil then
    return "nil"
  end
  local game = info.gameAccountInfo or {}
  local fields = {
    info.bnetAccountID,
    info.battleTag,
    info.isOnline,
    info.isAFK,
    info.isDND,
    game.isOnline,
    game.clientProgram,
    game.characterName,
    game.playerGuid,
    game.gameAccountID,
  }
  local parts = {}
  for i = 1, 10 do
    parts[i] = tostring(fields[i])
  end
  return table.concat(parts, "|")
end

local STATES = { "wow", "wow", "app", "app", "offline", "offline", "offline", "offline", "offline", "offline", "offline", "offline" }

return function()
  -- test_pass_cache_scans_friend_list_once_for_many_offline_friends

  do
    local api, calls = buildApi(STATES)
    local passCache = BNetResolver.NewPassCache()
    for id = 3, #STATES do
      BNetResolver.ResolveAccountInfo(api, id, nil, "Tag#" .. id, passCache)
    end
    assert(calls.friendInfo <= #STATES, "one walk of " .. #STATES .. " friends expected, got " .. calls.friendInfo .. " lookups")
  end

  -- test_pass_cache_returns_same_result_as_uncached_lookup

  do
    -- in WoW, app-only, offline, unknown ID, unknown ID healed by battle tag,
    -- ID that now belongs to another friend
    local cases = {
      { id = 1, tag = "Tag#1" },
      { id = 3, tag = "Tag#3" },
      { id = 5, tag = "Tag#5" },
      { id = 99, tag = "Tag#99" },
      { id = 99, tag = "Tag#6" },
      { id = 2, tag = "Tag#4" },
      { id = 7, tag = nil },
    }
    local cachedApi = buildApi(STATES)
    local passCache = BNetResolver.NewPassCache()
    for _, case in ipairs(cases) do
      local expected = summary(BNetResolver.ResolveAccountInfo(buildApi(STATES), case.id, nil, case.tag))
      local actual = summary(BNetResolver.ResolveAccountInfo(cachedApi, case.id, nil, case.tag, passCache))
      local label = "id " .. case.id .. " tag " .. tostring(case.tag)
      assert(actual == expected, label .. ": expected " .. expected .. ", got " .. actual)
    end
  end

  -- test_pass_cache_remembers_unresolved_account

  do
    local api, calls = buildApi(STATES)
    local passCache = BNetResolver.NewPassCache()
    assert(BNetResolver.ResolveAccountInfo(api, 99, nil, "Tag#99", passCache) == nil, "unknown friend")
    local friendInfoCalls, accountCalls = calls.friendInfo, calls.accountById
    assert(BNetResolver.ResolveAccountInfo(api, 99, nil, "Tag#99", passCache) == nil, "still unknown")
    assert(calls.friendInfo == friendInfoCalls, "a remembered miss must not walk the list again")
    assert(calls.accountById == accountCalls, "a remembered miss must not ask the API again")
  end

  -- test_resolve_without_cache_still_scans_fresh

  do
    local states = { "wow", "offline" }
    local api, calls = buildApi(states)
    local before = BNetResolver.ResolveAccountInfo(api, 2, nil, "Tag#2")
    assert(before.isOnline == nil, "offline friend: presence unknown at account level")
    local firstCalls = calls.friendInfo
    states[2] = "app"
    local after = BNetResolver.ResolveAccountInfo(api, 2, nil, "Tag#2")
    assert(after.isOnline == true, "the second uncached call must see the friend come online")
    assert(calls.friendInfo > firstCalls, "an uncached call scans the list again")
  end

  -- test_pass_cache_second_caller_sees_the_probed_account

  do
    local api, calls = buildApi(STATES)
    local passCache = BNetResolver.NewPassCache()
    local first = BNetResolver.ResolveAccountInfo(api, 3, nil, "Tag#3", passCache)
    local second = BNetResolver.ResolveAccountInfo(api, 3, nil, "Tag#3", passCache)
    assert(first.isOnline == true, "app-only friend is proven online by the game account probe")
    assert(second == first, "the second caller gets the already probed table")
    assert(calls.numGameAccounts == 1, "probed once, got " .. calls.numGameAccounts)
  end

  -- test_pass_cache_probed_index_entry_matches_uncached_for_a_later_caller

  do
    -- No GetAccountInfoByID: the probe mutates the shared friend-index table.
    local function withoutAccountLookup()
      local api = buildApi(STATES)
      api.GetAccountInfoByID = nil
      return api
    end
    local cachedApi = withoutAccountLookup()
    local passCache = BNetResolver.NewPassCache()
    BNetResolver.ResolveAccountInfo(cachedApi, 3, nil, "Tag#3", passCache)
    local later = BNetResolver.ResolveAccountInfo(cachedApi, 3, "Player-9", "Tag#3", passCache)
    local expected = BNetResolver.ResolveAccountInfo(withoutAccountLookup(), 3, "Player-9", "Tag#3")
    assert(summary(later) == summary(expected), "expected " .. summary(expected) .. ", got " .. summary(later))
  end

  -- test_pass_cache_keeps_contacts_sharing_a_stale_account_id_apart

  do
    local api = buildApi(STATES)
    local passCache = BNetResolver.NewPassCache()
    local own = BNetResolver.ResolveAccountInfo(api, 2, nil, "Tag#2", passCache)
    local healed = BNetResolver.ResolveAccountInfo(api, 2, nil, "Tag#5", passCache)
    assert(own.battleTag == "Tag#2", "ID 2 with its own tag is friend 2")
    assert(healed.battleTag == "Tag#5", "ID 2 saved for Tag#5 must resolve to friend 5, got " .. tostring(healed.battleTag))
  end

  -- test_pass_cache_serves_battle_tag_fallback_from_the_same_walk

  do
    local api, calls = buildApi(STATES)
    local passCache = BNetResolver.NewPassCache()
    for id = 5, 10 do
      local healed = BNetResolver.ResolveAccountInfo(api, 100 + id, nil, "Tag#" .. id, passCache)
      assert(healed.bnetAccountID == id, "stale ID healed by battle tag")
    end
    assert(calls.friendInfo <= #STATES, "battle tag fallback must reuse the walk, got " .. calls.friendInfo .. " lookups")
  end

  -- test_pass_cache_without_friend_list_matches_uncached

  do
    local savedGlobal = _G.BNGetNumFriends
    _G.BNGetNumFriends = nil
    local function withoutFriendList()
      local api = buildApi(STATES)
      api.GetNumFriends = nil
      api.GetAccountInfoByGUID = function(_guid)
        return accountInfo(6, "wow")
      end
      return api
    end
    -- stale ID (belongs to Tag#2), no readable friend list, guid known
    local expected = summary(BNetResolver.ResolveAccountInfo(withoutFriendList(), 2, "Player-1-6", "Tag#6"))
    local passCache = BNetResolver.NewPassCache()
    local actual = summary(BNetResolver.ResolveAccountInfo(withoutFriendList(), 2, "Player-1-6", "Tag#6", passCache))
    _G.BNGetNumFriends = savedGlobal
    assert(actual == expected, "expected " .. expected .. ", got " .. actual)
  end
end
