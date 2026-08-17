local LifecycleHandlers = require("WhisperMessenger.Core.Bootstrap.LifecycleHandlers")
local Store = require("WhisperMessenger.Model.ConversationStore")
local GroupChatIngest = require("WhisperMessenger.Core.Ingest.GroupChatIngest")

return function()
  -- Save and restore WoW globals touched by these tests
  local savedIsInGroup = _G.IsInGroup
  local savedIsInRaid = _G.IsInRaid
  local savedLE_HOME = _G.LE_PARTY_CATEGORY_HOME
  local savedLE_INSTANCE = _G.LE_PARTY_CATEGORY_INSTANCE
  local savedTime = _G.time
  local savedDate = _G.date
  _G.date = _G.date or os.date

  _G.LE_PARTY_CATEGORY_HOME = 1
  _G.LE_PARTY_CATEGORY_INSTANCE = 2
  _G.time = function()
    return 5000
  end

  local LOCAL_PROFILE_ID = "me"
  local PARTY_KEY = "party::" .. LOCAL_PROFILE_ID
  local RAID_KEY = "raid::" .. LOCAL_PROFILE_ID
  local INSTANCE_KEY = "instance::" .. LOCAL_PROFILE_ID
  local FOREIGN_PARTY_KEY = "party::other-realm"

  local function makeState(conversations)
    return {
      conversations = conversations,
      activeConversationKey = nil,
    }
  end

  local function makeBootstrap(state, onRefresh)
    return {
      runtime = {
        accountState = state,
        localProfileId = LOCAL_PROFILE_ID,
        refreshWindow = onRefresh or function() end,
      },
    }
  end

  local function makeDeps(trace)
    return {
      trace = trace or function() end,
      getContentDetector = function()
        return nil
      end,
      getPresenceCache = function()
        return nil
      end,
      loadModule = function()
        return nil
      end,
    }
  end

  local function lastMessage(conversation)
    local messages = conversation.messages or {}
    return messages[#messages]
  end

  -- test_group_roster_update_leaving_all_groups_appends_left_messages
  do
    _G.IsInGroup = function(_category)
      return false
    end
    _G.IsInRaid = function()
      return false
    end

    local state = makeState({
      [PARTY_KEY] = { channel = "PARTY", messages = {} },
      [INSTANCE_KEY] = { channel = "INSTANCE_CHAT", messages = {} },
      [RAID_KEY] = { channel = "RAID", messages = {} },
      ["whisper::Carol"] = { channel = "WHISPER", messages = {} },
      ["bnconv::1"] = { channel = "BN_CONVERSATION", messages = {} },
    })
    local refreshCalled = false
    local Bootstrap = makeBootstrap(state, function()
      refreshCalled = true
    end)

    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())

    assert(state.conversations[PARTY_KEY] ~= nil, "PARTY conversation must NOT be purged")
    assert(state.conversations[INSTANCE_KEY] ~= nil, "INSTANCE conversation must NOT be purged")
    assert(state.conversations[RAID_KEY] ~= nil, "RAID conversation must NOT be purged")
    assert(state.conversations[PARTY_KEY].leftGroup == true, "PARTY should be marked as left")
    assert(state.conversations[INSTANCE_KEY].leftGroup == true, "INSTANCE should be marked as left")
    assert(state.conversations[RAID_KEY].leftGroup == true, "RAID should be marked as left")

    assert(string.find(lastMessage(state.conversations[PARTY_KEY]).text, "Left party", 1, true) == 1, "PARTY left message text")
    assert(string.find(lastMessage(state.conversations[INSTANCE_KEY]).text, "Left instance", 1, true) == 1, "INSTANCE left message text")
    assert(string.find(lastMessage(state.conversations[RAID_KEY]).text, "Left raid", 1, true) == 1, "RAID left message text")
    assert(lastMessage(state.conversations[PARTY_KEY]).kind == "system", "left message should be system")

    assert(state.conversations["whisper::Carol"].leftGroup == nil, "WHISPER should not get a leftGroup flag")
    assert(state.conversations["bnconv::1"].leftGroup == nil, "BN_CONVERSATION should not get a leftGroup flag")
    assert(refreshCalled == true, "refreshWindow should be called after marking transitions")
  end

  -- test_group_roster_update_leave_message_recorded_once_per_departure
  do
    _G.IsInGroup = function(_category)
      return false
    end
    _G.IsInRaid = function()
      return false
    end

    local state = makeState({
      [PARTY_KEY] = { channel = "PARTY", messages = {} },
    })
    local Bootstrap = makeBootstrap(state)

    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())
    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())
    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())

    assert(
      #state.conversations[PARTY_KEY].messages == 1,
      "expected exactly one Left-party message after repeated roster updates, got " .. #state.conversations[PARTY_KEY].messages
    )
  end

  -- test_group_roster_update_rejoining_clears_left_flag_so_future_leave_records_again
  do
    local inGroup = false
    _G.IsInGroup = function(_category)
      return inGroup
    end
    _G.IsInRaid = function()
      return false
    end

    local state = makeState({
      [PARTY_KEY] = { channel = "PARTY", messages = {} },
    })
    local Bootstrap = makeBootstrap(state)

    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())
    assert(state.conversations[PARTY_KEY].leftGroup == true, "after leave, leftGroup=true")
    assert(#state.conversations[PARTY_KEY].messages == 1, "one left-message after first leave")

    inGroup = true
    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())
    assert(state.conversations[PARTY_KEY].leftGroup == nil, "rejoin clears leftGroup flag")

    inGroup = false
    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())
    assert(
      #state.conversations[PARTY_KEY].messages == 2,
      "second leave should append a second left-message, got " .. #state.conversations[PARTY_KEY].messages
    )
  end

  -- test_group_roster_update_in_home_not_instance_keeps_party_marks_instance
  do
    _G.IsInGroup = function(category)
      return category == _G.LE_PARTY_CATEGORY_HOME
    end
    _G.IsInRaid = function()
      return false
    end

    local state = makeState({
      [PARTY_KEY] = { channel = "PARTY", messages = {} },
      [INSTANCE_KEY] = { channel = "INSTANCE_CHAT", messages = {} },
      ["whisper::Carol"] = { channel = "WHISPER", messages = {} },
    })
    local Bootstrap = makeBootstrap(state)

    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())

    assert(state.conversations[PARTY_KEY].leftGroup == nil, "PARTY should NOT be marked left while in home group")
    assert(#state.conversations[PARTY_KEY].messages == 0, "PARTY should not receive a left-message")
    assert(state.conversations[INSTANCE_KEY].leftGroup == true, "INSTANCE should be marked left")
    assert(string.find(lastMessage(state.conversations[INSTANCE_KEY]).text, "Left instance", 1, true) == 1, "INSTANCE left message")
    assert(state.conversations["whisper::Carol"].leftGroup == nil, "WHISPER unaffected")
  end

  -- test_group_roster_update_ignores_foreign_character_group_conversations
  -- Another character's party/raid/instance history must be left alone:
  -- GROUP_ROSTER_UPDATE reports the current character's membership, not
  -- the alt's, so touching foreign rows would spam duplicate "Left …"
  -- messages every time the current character joins or leaves a group.
  do
    _G.IsInGroup = function(_category)
      return false
    end
    _G.IsInRaid = function()
      return false
    end

    local state = makeState({
      [FOREIGN_PARTY_KEY] = { channel = "PARTY", messages = {}, leftGroup = true },
    })
    local Bootstrap = makeBootstrap(state)

    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())

    assert(#state.conversations[FOREIGN_PARTY_KEY].messages == 0, "foreign-character party should NOT receive a left message")
    assert(state.conversations[FOREIGN_PARTY_KEY].leftGroup == true, "foreign-character leftGroup flag must stay intact")

    -- Now the current character joins a party — foreign row must still not move.
    _G.IsInGroup = function(category)
      return category == _G.LE_PARTY_CATEGORY_HOME
    end

    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())

    assert(
      state.conversations[FOREIGN_PARTY_KEY].leftGroup == true,
      "current character joining a party must NOT clear leftGroup on another character's row"
    )
  end

  -- test_group_roster_update_nil_is_in_group_noop
  do
    _G.IsInGroup = nil

    local state = makeState({
      [PARTY_KEY] = { channel = "PARTY", messages = {} },
    })
    local Bootstrap = makeBootstrap(state)

    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())

    assert(state.conversations[PARTY_KEY] ~= nil, "PARTY kept when IsInGroup is nil (Classic compat)")
    assert(state.conversations[PARTY_KEY].leftGroup == nil, "no leftGroup flag when IsInGroup is nil (Classic compat)")
    assert(#state.conversations[PARTY_KEY].messages == 0, "no system message when IsInGroup is nil")
  end

  -- test_player_logout_keeps_group_conversations_for_persistence
  do
    _G.IsInGroup = function(_category)
      return false
    end

    local state = makeState({
      [PARTY_KEY] = { channel = "PARTY" },
      [RAID_KEY] = { channel = "RAID" },
      [INSTANCE_KEY] = { channel = "INSTANCE_CHAT" },
      ["whisper::Carol"] = { channel = "WHISPER" },
      ["bnconv::1"] = { channel = "BN_CONVERSATION" },
    })
    local Bootstrap = {
      runtime = {
        accountState = state,
        localProfileId = LOCAL_PROFILE_ID,
        store = { conversations = state.conversations },
      },
    }

    LifecycleHandlers.Handle(Bootstrap, "PLAYER_LOGOUT", makeDeps())

    assert(state.conversations[PARTY_KEY] ~= nil, "PARTY survives logout (persistence)")
    assert(state.conversations[RAID_KEY] ~= nil, "RAID survives logout (persistence)")
    assert(state.conversations[INSTANCE_KEY] ~= nil, "INSTANCE survives logout (persistence)")
    assert(state.conversations["whisper::Carol"] ~= nil, "WHISPER survives logout")
    assert(state.conversations["bnconv::1"] ~= nil, "BN_CONVERSATION survives logout")
  end

  -- test_group_join_closes_replaced_guid_when_leave_was_missed
  do
    local store = Store.New({ maxMessagesPerConversation = 50 })
    local state = makeState(store.conversations)
    local refreshCalls = 0
    local Bootstrap = makeBootstrap(state, function()
      refreshCalls = refreshCalls + 1
    end)
    Bootstrap.runtime.store = store
    Bootstrap.runtime.groupPartyGUIDsByCategory = {}

    local partyGuidA = "Party-0-0000000000000003"
    local partyGuidB = "Party-0-0000000000000004"
    local category = _G.LE_PARTY_CATEGORY_HOME
    local partyKeyA = "party::" .. LOCAL_PROFILE_ID .. "::" .. category .. "::" .. partyGuidA

    LifecycleHandlers.Handle(Bootstrap, "GROUP_FORMED", makeDeps(), category, partyGuidA)
    LifecycleHandlers.Handle(Bootstrap, "GROUP_JOINED", makeDeps(), category, partyGuidA)
    GroupChatIngest.HandleEvent(Bootstrap.runtime, "CHAT_MSG_PARTY", {
      text = "group A",
      playerName = "Member-Realm",
      lineID = 10003,
      guid = "Player-1084-00000099",
    })

    LifecycleHandlers.Handle(Bootstrap, "GROUP_JOINED", makeDeps(), category, partyGuidB)

    local conversationA = store.conversations[partyKeyA]
    assert(conversationA.leftGroup == true, "joining group B must close group A when GROUP_LEFT was missed")
    assert(#conversationA.messages == 2, "group A should have one message and one Left notice")
    assert(conversationA.messages[2].kind == "system", "group A should record a Left system message")
    assert(refreshCalls == 1, "replacing group A should refresh once")
    assert(Bootstrap.runtime.groupPartyGUIDsByCategory[category] == partyGuidB, "group B should become current")

    LifecycleHandlers.Handle(Bootstrap, "GROUP_JOINED", makeDeps(), category, partyGuidB)

    assert(#conversationA.messages == 2, "rejoining current group B must not append another Left notice")
    assert(refreshCalls == 1, "rejoining current group B must not refresh")
  end

  -- test_group_lifecycle_guid_sessions_remain_separate_after_rejoin
  do
    local inHomeGroup = true
    _G.IsInGroup = function(category)
      return category == _G.LE_PARTY_CATEGORY_HOME and inHomeGroup
    end
    _G.IsInRaid = function()
      return false
    end

    local store = Store.New({ maxMessagesPerConversation = 50 })
    local state = makeState(store.conversations)
    local Bootstrap = makeBootstrap(state)
    Bootstrap.runtime.store = store
    Bootstrap.runtime.groupPartyGUIDsByCategory = {}

    local partyGuidA = "Party-0-0000000000000001"
    local partyGuidB = "Party-0-0000000000000002"
    local category = _G.LE_PARTY_CATEGORY_HOME
    local partyKeyA = "party::" .. LOCAL_PROFILE_ID .. "::" .. category .. "::" .. partyGuidA
    local partyKeyB = "party::" .. LOCAL_PROFILE_ID .. "::" .. category .. "::" .. partyGuidB

    LifecycleHandlers.Handle(Bootstrap, "GROUP_FORMED", makeDeps(), category, partyGuidA)
    assert(Bootstrap.runtime.groupPartyGUIDsByCategory[category] == partyGuidA, "GROUP_FORMED should capture group A")
    LifecycleHandlers.Handle(Bootstrap, "GROUP_JOINED", makeDeps(), category, partyGuidA)
    assert(Bootstrap.runtime.groupPartyGUIDsByCategory[category] == partyGuidA, "GROUP_JOINED should retain group A")

    GroupChatIngest.HandleEvent(Bootstrap.runtime, "CHAT_MSG_PARTY", {
      text = "group A",
      playerName = "Member-Realm",
      lineID = 10001,
      guid = "Player-1084-00000099",
    })

    LifecycleHandlers.Handle(Bootstrap, "GROUP_LEFT", makeDeps(), category, partyGuidA)

    LifecycleHandlers.Handle(Bootstrap, "GROUP_JOINED", makeDeps(), category, partyGuidB)
    GroupChatIngest.HandleEvent(Bootstrap.runtime, "CHAT_MSG_PARTY", {
      text = "group B",
      playerName = "Member-Realm",
      lineID = 10002,
      guid = "Player-1084-00000099",
    })
    LifecycleHandlers.Handle(Bootstrap, "GROUP_LEFT", makeDeps(), category, partyGuidA)
    LifecycleHandlers.Handle(Bootstrap, "GROUP_ROSTER_UPDATE", makeDeps())

    local conversationA = store.conversations[partyKeyA]
    local conversationB = store.conversations[partyKeyB]
    assert(conversationA ~= nil, "group A session should exist at " .. partyKeyA)
    assert(conversationB ~= nil, "group B session should exist at " .. partyKeyB)
    assert(#conversationA.messages == 2, "group A should retain one message and one Left notice")
    assert(conversationA.leftGroup == true, "group A should stay closed after joining group B")
    assert(conversationA.messages[2].kind == "system", "group A should record one Left system message")
    assert(#conversationB.messages == 1, "roster update should not create another group B thread")
    assert(conversationB.leftGroup == nil, "active group B should remain open")
    assert(conversationB.ownerProfileId == LOCAL_PROFILE_ID, "group B should be stamped with current owner")
    assert(conversationB.groupCategory == category, "group B should retain its party category")
    assert(conversationB.partyGUID == partyGuidB, "group B should retain its party GUID")
    assert(Bootstrap.runtime.groupPartyGUIDsByCategory[category] == partyGuidB, "stale GROUP_LEFT must not clear group B mapping")
    assert(store.conversations["party::" .. LOCAL_PROFILE_ID] == nil, "known party GUID must not use singleton key")
  end

  -- Restore globals
  _G.IsInGroup = savedIsInGroup
  _G.IsInRaid = savedIsInRaid
  _G.LE_PARTY_CATEGORY_HOME = savedLE_HOME
  _G.LE_PARTY_CATEGORY_INSTANCE = savedLE_INSTANCE
  _G.time = savedTime
  _G.date = savedDate
end
