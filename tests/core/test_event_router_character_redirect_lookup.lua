local WhisperMessage = require("WhisperMessenger.Core.EventRouter.WhisperMessage")
local CharacterRedirect = require("WhisperMessenger.Core.EventRouter.CharacterRedirect")
local World = require("tests.helpers.character_merge_world")

local K, B, NAME, FRIEND = World.K, World.B, World.NAME, World.FRIEND
local newState = World.NewState

local function resolve(state, payload)
  payload = payload or { playerName = NAME, guid = "Player-1", text = "hi", lineID = 1 }
  local contact, key = WhisperMessage.BuildConversationContact(state, payload)
  return CharacterRedirect.Resolve(state, contact, key, payload)
end

local function withSecret(isSecret, fn)
  local saved = _G.issecretvalue
  _G.issecretvalue = isSecret
  local ok, err = pcall(fn)
  _G.issecretvalue = saved
  assert(ok, err)
end

local function test_no_guid_skips_lookup_and_caches_no_miss()
  local state, lookups = newState(FRIEND)
  assert(resolve(state, { playerName = NAME, text = "hi" }) == K and lookups.n == 0, "no GUID: K, no lookup")
  assert(resolve(state) == B and lookups.n == 1, "a later event with a GUID still matches")
end

local function test_empty_guid_skips_lookup_and_caches_no_miss()
  local state = newState()
  local asked = {}
  state.bnetApi.GetAccountInfoByGUID = function(guid)
    asked[#asked + 1] = guid
    return guid == "Player-1" and FRIEND or nil
  end
  resolve(state, { playerName = NAME, guid = "", text = "hi" })
  local key = resolve(state)
  assert(key == B and #asked == 1, "an empty GUID is never looked up, so a later real GUID still matches, got " .. #asked .. " lookups")
end

local function test_secret_guid_skips_lookup()
  local state, lookups = newState(FRIEND)
  withSecret(function(value)
    return value == "Player-1"
  end, function()
    assert(resolve(state) == K and lookups.n == 0, "a secret GUID is never passed to the API")
  end)
end

local function test_missing_lookup_function_keeps_k()
  local state = newState(FRIEND)
  state.bnetApi = {}
  assert(resolve(state) == K, "no GetAccountInfoByGUID: K")
end

local function test_missing_battle_net_api_keeps_k()
  local state = newState(FRIEND)
  state.bnetApi = nil
  assert(resolve(state) == K, "no Battle.net API at all: K")
end

local function test_api_error_is_a_miss()
  local state = newState(FRIEND)
  state.bnetApi.GetAccountInfoByGUID = function()
    error("not available")
  end
  assert(resolve(state) == K, "a failing lookup keeps K and does not raise")
end

local function test_api_error_caches_the_miss()
  local state = newState()
  local lookups = 0
  state.bnetApi.GetAccountInfoByGUID = function()
    lookups = lookups + 1
    error("not available")
  end
  resolve(state)
  resolve(state)
  assert(lookups == 1, "a failing lookup is a miss, cached for the session, got " .. lookups .. " lookups")
end

local function test_no_match_is_looked_up_once_per_session()
  local state, lookups = newState(nil)
  resolve(state)
  resolve(state)
  assert(lookups.n == 1 and state.characterMergeMisses[K] == true, "a miss is cached, got " .. lookups.n .. " lookups")
end

local function test_account_without_battle_tag_is_no_match()
  local state = newState({ bnetAccountID = 7 })
  assert(resolve(state) == K and state.store.conversations[B] == nil, "no battleTag: no merge")
end

local function test_empty_battle_tag_is_no_match()
  local state = newState({ bnetAccountID = 7, battleTag = "" })
  assert(resolve(state) == K and state.store.conversations[B] == nil, "an empty battleTag: no merge")
end

local function test_secret_account_id_is_not_kept()
  local state = newState(FRIEND)
  withSecret(function(value)
    return value == 77
  end, function()
    assert(resolve(state) == B, "the battleTag alone still matches")
  end)
  local merged = state.store.conversations[B]
  assert(merged.bnetAccountID == nil, "a secret account id is not stored, got " .. tostring(merged.bnetAccountID))
end

local function test_secret_battle_tag_is_no_match()
  local state = newState(FRIEND)
  withSecret(function(value)
    return value == "Jaina#1234"
  end, function()
    assert(resolve(state) == K and state.store.conversations[B] == nil, "a secret battleTag is no match")
  end)
end

local function test_account_that_is_not_a_friend_is_no_match()
  local state = newState({ bnetAccountID = 77, battleTag = "Jaina#1234", isFriend = false })
  assert(resolve(state) == K and state.store.conversations[B] == nil, "an account that is not a friend: no merge")
end

local function test_account_marked_as_friend_matches()
  local state = newState({ bnetAccountID = 77, battleTag = "Jaina#1234", isFriend = true })
  assert(resolve(state) == B, "a friend's account merges")
end

local function test_secret_friend_flag_is_no_match()
  local state = newState({ bnetAccountID = 77, battleTag = "Jaina#1234", isFriend = true })
  withSecret(function(value)
    return value == true
  end, function()
    assert(resolve(state) == K and state.store.conversations[B] == nil, "a friend flag the client hides is no match")
  end)
end

local function test_secret_name_skips_lookup()
  local state, lookups = newState(FRIEND)
  withSecret(function(value)
    return value == NAME
  end, function()
    assert(resolve(state) == K and lookups.n == 0, "a secret name is never saved into the merge map")
  end)
end

return function()
  test_no_guid_skips_lookup_and_caches_no_miss()
  test_empty_guid_skips_lookup_and_caches_no_miss()
  test_secret_guid_skips_lookup()
  test_missing_lookup_function_keeps_k()
  test_missing_battle_net_api_keeps_k()
  test_api_error_is_a_miss()
  test_api_error_caches_the_miss()
  test_no_match_is_looked_up_once_per_session()
  test_account_without_battle_tag_is_no_match()
  test_empty_battle_tag_is_no_match()
  test_secret_account_id_is_not_kept()
  test_secret_battle_tag_is_no_match()
  test_account_that_is_not_a_friend_is_no_match()
  test_account_marked_as_friend_matches()
  test_secret_friend_flag_is_no_match()
  test_secret_name_skips_lookup()
end
