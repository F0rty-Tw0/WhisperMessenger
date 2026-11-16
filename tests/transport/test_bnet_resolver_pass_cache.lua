local PassCache = require("WhisperMessenger.Transport.BNetResolver.PassCache")

local function identity(value)
  return value
end

-- friends[i] is the account info of friend i; false = the lookup returns
-- nil, "error" = the lookup throws.
local function buildApi(friends)
  local calls = { numFriends = 0, friendInfo = 0 }
  local api = {
    GetNumFriends = function()
      calls.numFriends = calls.numFriends + 1
      return #friends
    end,
    GetFriendAccountInfo = function(i)
      calls.friendInfo = calls.friendInfo + 1
      if friends[i] == "error" then
        error("friend lookup failed")
      end
      return friends[i] or nil
    end,
  }
  return api, calls
end

return function()
  -- test_new_cache_starts_empty

  do
    local passCache = PassCache.New(identity)
    assert(next(passCache.results) == nil, "a new cache holds no results")
    assert(passCache.index == nil, "the friend index is built on first need")
  end

  -- test_lookup_misses_until_a_result_is_remembered

  do
    local passCache = PassCache.New(identity)
    local found, value = PassCache.Lookup(passCache, 7, "Player-1", "Tag#7")
    assert(found == false and value == nil, "nothing remembered yet")

    local info = { bnetAccountID = 7 }
    assert(PassCache.Remember(passCache, 7, "Player-1", "Tag#7", info) == info, "Remember returns the stored value")
    found, value = PassCache.Lookup(passCache, 7, "Player-1", "Tag#7")
    assert(found == true and value == info, "the remembered result comes back")
  end

  -- test_unresolved_account_is_remembered_as_found

  do
    local passCache = PassCache.New(identity)
    PassCache.Remember(passCache, 7, nil, nil, nil)
    local found, value = PassCache.Lookup(passCache, 7, nil, nil)
    assert(found == true and value == nil, "a miss must be remembered too")
  end

  -- test_results_are_kept_apart_by_guid_and_battle_tag

  do
    local passCache = PassCache.New(identity)
    local first = { battleTag = "Tag#1" }
    local second = { battleTag = "Tag#2" }
    PassCache.Remember(passCache, 7, "Player-1", "Tag#1", first)
    PassCache.Remember(passCache, 7, "Player-1", "Tag#2", second)
    local _, viaFirstTag = PassCache.Lookup(passCache, 7, "Player-1", "Tag#1")
    local _, viaSecondTag = PassCache.Lookup(passCache, 7, "Player-1", "Tag#2")
    assert(viaFirstTag == first and viaSecondTag == second, "same ID with another battle tag is another result")
    assert(PassCache.Lookup(passCache, 7, "Player-2", "Tag#1") == false, "same ID with another guid is not cached")
  end

  -- test_friend_index_walks_the_list_once

  do
    local friends = {
      { bnetAccountID = 11, battleTag = "Tag#11" },
      { bnetAccountID = 12, battleTag = "Tag#12" },
      { bnetAccountID = 13, battleTag = "Tag#13" },
    }
    local api, calls = buildApi(friends)
    local passCache = PassCache.New(identity)

    local info, friendIndex = PassCache.FindByAccountId(passCache, api, 13)
    assert(info.bnetAccountID == 13 and friendIndex == 3, "found by account ID with its list position")
    local byTag, tagIndex, listAvailable = PassCache.FindByBattleTag(passCache, api, "Tag#12")
    assert(byTag.battleTag == "Tag#12" and tagIndex == 2 and listAvailable == true, "found by battle tag from the same walk")
    assert(PassCache.FindByAccountId(passCache, api, 99) == nil, "unknown ID")
    local missing, _, stillAvailable = PassCache.FindByBattleTag(passCache, api, "Tag#99")
    assert(missing == nil and stillAvailable == true, "unknown tag on a readable list")

    assert(calls.friendInfo == 3, "one walk for every lookup, got " .. calls.friendInfo)
    assert(calls.numFriends == 1, "friend count read once, got " .. calls.numFriends)
  end

  -- test_first_friend_wins_for_a_repeated_id_or_tag

  do
    local friends = {
      { bnetAccountID = 11, battleTag = "Tag#11" },
      { bnetAccountID = 11, battleTag = "Tag#11" },
    }
    local api = buildApi(friends)
    local passCache = PassCache.New(identity)
    local info, friendIndex = PassCache.FindByAccountId(passCache, api, 11)
    assert(info.bnetAccountID == 11 and friendIndex == 1, "the uncached scan stops at the first match")
    local byTag, tagIndex = PassCache.FindByBattleTag(passCache, api, "Tag#11")
    assert(byTag.battleTag == "Tag#11" and tagIndex == 1, "first battle tag match wins")
  end

  -- test_failing_friend_lookups_are_skipped

  do
    local friends = { "error", false, { bnetAccountID = 13, battleTag = "Tag#13" } }
    local api = buildApi(friends)
    local passCache = PassCache.New(identity)
    local info, friendIndex = PassCache.FindByAccountId(passCache, api, 13)
    assert(info.bnetAccountID == 13 and friendIndex == 3, "a failing or empty entry must not stop the walk")
  end

  -- test_account_ids_the_sanitizer_rejects_are_not_indexed

  do
    local friends = { { bnetAccountID = 11, battleTag = "Tag#11" } }
    local api = buildApi(friends)
    local passCache = PassCache.New(function(_value)
      return nil
    end)
    assert(PassCache.FindByAccountId(passCache, api, 11) == nil, "an unreadable ID is not a match")
    assert(PassCache.FindByBattleTag(passCache, api, "Tag#11").battleTag == "Tag#11", "the battle tag still is")
  end

  -- test_unreadable_friend_list_is_reported

  do
    local savedGlobal = _G.BNGetNumFriends
    _G.BNGetNumFriends = nil
    local passCache = PassCache.New(identity)
    local info, friendIndex, listAvailable = PassCache.FindByBattleTag(passCache, {}, "Tag#11")
    _G.BNGetNumFriends = savedGlobal
    assert(info == nil and friendIndex == nil, "no friend list, no match")
    assert(listAvailable == false, "the caller must be able to tell 'not listed' from 'no list'")
  end
end
