local MessageRequests = require("WhisperMessenger.Model.MessageRequests")

-- Requests inbox: whispers from strangers can be parked in a Requests tab.
-- Identity checks fail open: when anything is unknown the whisper is NOT a
-- request, so a real whisper is never hidden.

local GUID = "Player-1-ABC"
local NAME = "Stranger-Realm"

local function stubStrangerApis()
  rawset(_G, "IsGuildMember", function()
    return false
  end)
  rawset(_G, "UnitInParty", function()
    return false
  end)
  rawset(_G, "UnitInRaid", function()
    return nil
  end)
  rawset(_G, "IsGUIDInGroup", function()
    return false
  end)
  return {
    friendListApi = {
      IsFriend = function()
        return false
      end,
    },
    bnetApi = {
      GetGameAccountInfoByGUID = function()
        return nil
      end,
    },
    accountState = { settings = { requestsInbox = true } },
  }
end

local function clearGlobals()
  rawset(_G, "IsGuildMember", nil)
  rawset(_G, "UnitInParty", nil)
  rawset(_G, "UnitInRaid", nil)
  rawset(_G, "IsGUIDInGroup", nil)
end

local function newConversation()
  return { channel = "WOW", messages = { { kind = "user", direction = "in" } } }
end

return function()
  -- test_is_request_needs_setting_and_flag
  do
    assert(MessageRequests.IsRequest({ request = true }, { requestsInbox = true }) == true, "flag + setting on = request")
    assert(MessageRequests.IsRequest({ request = true }, { requestsInbox = false }) == false, "setting off ignores the flag")
    assert(MessageRequests.IsRequest({ request = true }, nil) == false, "no settings = not a request")
    assert(MessageRequests.IsRequest({}, { requestsInbox = true }) == false, "no flag = not a request")
    assert(MessageRequests.IsRequest(nil, { requestsInbox = true }) == false, "no conversation = not a request")
  end

  -- test_stranger_is_classified_as_request
  do
    local runtime = stubStrangerApis()
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == true, "a whisper from nobody you know is a request")
  end

  -- test_setting_off_never_classifies
  do
    local runtime = stubStrangerApis()
    runtime.accountState.settings.requestsInbox = false
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == nil, "setting off: behaves exactly as before")
  end

  -- test_character_friend_is_not_a_request
  do
    local runtime = stubStrangerApis()
    runtime.friendListApi.IsFriend = function(guid)
      return guid == GUID
    end
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == nil, "character friend is never a request")
  end

  -- test_guild_member_is_not_a_request
  do
    local runtime = stubStrangerApis()
    rawset(_G, "IsGuildMember", function()
      return true
    end)
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == nil, "guild member is never a request")
  end

  -- test_bnet_friend_character_is_not_a_request
  do
    local runtime = stubStrangerApis()
    runtime.bnetApi.GetGameAccountInfoByGUID = function()
      return { gameAccountID = 7 }
    end
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == nil, "a Battle.net friend's character is never a request")
  end

  -- test_group_member_is_not_a_request
  do
    local runtime = stubStrangerApis()
    rawset(_G, "UnitInRaid", function()
      return 3
    end)
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == nil, "raid member is never a request")
    rawset(_G, "UnitInRaid", function()
      return nil
    end)
    rawset(_G, "UnitInParty", function()
      return true
    end)
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == nil, "party member is never a request")
  end

  -- test_group_member_by_guid_is_not_a_request_when_name_lookup_misses
  do
    local runtime = stubStrangerApis()
    rawset(_G, "IsGUIDInGroup", function(guid)
      return guid == GUID
    end)
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == nil, "a group member matched by GUID is never a request")
  end

  -- test_throwing_guid_group_check_fails_open
  do
    local runtime = stubStrangerApis()
    rawset(_G, "IsGUIDInGroup", function()
      error("secret value")
    end)
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == nil, "an error from the GUID group check never hides a whisper")
  end

  -- test_missing_guid_group_api_is_skipped
  do
    local runtime = stubStrangerApis()
    rawset(_G, "IsGUIDInGroup", nil)
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == true, "clients without the GUID check still use the name checks")
  end

  -- test_missing_api_fails_open
  do
    local runtime = stubStrangerApis()
    rawset(_G, "IsGuildMember", nil)
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == nil, "unknown guild status: not a request")
  end

  -- test_throwing_api_fails_open
  do
    local runtime = stubStrangerApis()
    runtime.friendListApi.IsFriend = function()
      error("secret value")
    end
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == nil, "an API error (chat lockdown) never hides a whisper")
  end

  -- test_missing_guid_fails_open
  do
    local runtime = stubStrangerApis()
    local conversation = newConversation()
    MessageRequests.ClassifyNew(runtime, conversation, nil, NAME)
    assert(conversation.request == nil, "no GUID: not a request")
  end

  -- test_battle_net_conversation_is_never_a_request
  do
    local runtime = stubStrangerApis()
    local conversation = newConversation()
    conversation.channel = "BN"
    MessageRequests.ClassifyNew(runtime, conversation, GUID, NAME)
    assert(conversation.request == nil, "Battle.net whispers are never requests")
  end

  -- test_accept_clears_the_flag
  do
    local store = { conversations = { k = { request = true } } }
    MessageRequests.Accept(store, "k")
    assert(store.conversations.k.request == nil, "accept moves it to Whispers")
    MessageRequests.Accept(store, "missing")
  end

  clearGlobals()
end
