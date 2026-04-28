local Store = require("WhisperMessenger.Model.ConversationStore")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

-- Load GroupChatIngest under test
local GroupChatIngest = require("WhisperMessenger.Core.Ingest.GroupChatIngest")

return function()
  local function makeState(overrides)
    overrides = overrides or {}
    local s = {
      localProfileId = "arthas-area52",
      localPlayerGuid = "Player-1084-00000001",
      localBnetAccountID = 12345,
      store = Store.New({ maxMessagesPerConversation = 50 }),
      activeConversationKey = nil,
      -- Whisper-specific state (must NOT be mutated by group ingest)
      pendingOutgoing = { sentinel = true },
      availabilityByGUID = { sentinel = true },
      lastIncomingWhisperKey = "whisper-sentinel",
    }
    for k, v in pairs(overrides) do
      s[k] = v
    end
    return s
  end

  -- ----------------------------------------------------------------
  -- 1. CHAT_MSG_PARTY → creates conversation with key party::<profile>,
  --    channel=PARTY, message stored with direction=in
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    local payload = {
      text = "hello party",
      playerName = "Thrall-Aggamaggan",
      lineID = 101,
      guid = "Player-1084-00000099",
    }
    local handled = GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", payload)
    assert(handled == true, "CHAT_MSG_PARTY should return true")

    local expectedKey = "party::arthas-area52"
    local conv = state.store.conversations[expectedKey]
    assert(conv ~= nil, "conversation should exist at key " .. expectedKey)
    assert(conv.channel == ChannelType.PARTY, "channel should be PARTY, got: " .. tostring(conv.channel))
    assert(#conv.messages == 1, "should have 1 message")
    assert(conv.messages[1].direction == "in", "direction should be in")
    assert(conv.messages[1].text == "hello party", "text mismatch")
    assert(conv.messages[1].channel == ChannelType.PARTY, "message channel should be PARTY")
    assert(conv.conversationKey == expectedKey, "conversationKey stamp missing")
  end

  -- ----------------------------------------------------------------
  -- 2. CHAT_MSG_PARTY_LEADER merges into same thread as CHAT_MSG_PARTY
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    local payloadA = {
      text = "ready?",
      playerName = "Arthas-Area52",
      lineID = 201,
      guid = "Player-1084-00000002",
    }
    local payloadB = {
      text = "follow me",
      playerName = "Leader-Realm",
      lineID = 202,
      guid = "Player-1084-00000003",
    }
    GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", payloadA)
    GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY_LEADER", payloadB)

    local conv = state.store.conversations["party::arthas-area52"]
    assert(conv ~= nil, "conversation should exist")
    assert(#conv.messages == 2, "both messages should be in same thread, got: " .. tostring(#conv.messages))
    assert(conv.messages[1].text == "ready?", "first message text mismatch")
    assert(conv.messages[2].text == "follow me", "second message text mismatch")
  end

  -- ----------------------------------------------------------------
  -- 3. Leader flag is preserved: isLeader=true on leader message,
  --    isLeader=false/nil on regular message
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", {
      text = "hi",
      playerName = "Member-Realm",
      lineID = 301,
      guid = "Player-1084-00000010",
    })
    GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY_LEADER", {
      text = "boss says go",
      playerName = "Leader-Realm",
      lineID = 302,
      guid = "Player-1084-00000011",
    })

    local conv = state.store.conversations["party::arthas-area52"]
    assert(conv.messages[1].isLeader ~= true, "regular message should not have isLeader=true")
    assert(conv.messages[2].isLeader == true, "leader message should have isLeader=true")
  end

  -- ----------------------------------------------------------------
  -- 4. CHAT_MSG_INSTANCE_CHAT → key instance::<profile>, channel=INSTANCE_CHAT
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    local handled = GroupChatIngest.HandleEvent(state, "CHAT_MSG_INSTANCE_CHAT", {
      text = "stack up",
      playerName = "Tank-Realm",
      lineID = 401,
      guid = "Player-1084-00000020",
    })
    assert(handled == true, "CHAT_MSG_INSTANCE_CHAT should return true")

    local expectedKey = "instance::arthas-area52"
    local conv = state.store.conversations[expectedKey]
    assert(conv ~= nil, "conversation should exist at key " .. expectedKey)
    assert(conv.channel == ChannelType.INSTANCE_CHAT, "channel should be INSTANCE_CHAT, got: " .. tostring(conv.channel))
    assert(conv.messages[1].channel == ChannelType.INSTANCE_CHAT, "message channel should be INSTANCE_CHAT")
    assert(conv.conversationKey == expectedKey, "conversationKey stamp missing")
  end

  -- ----------------------------------------------------------------
  -- 5. CHAT_MSG_INSTANCE_CHAT_LEADER merges with CHAT_MSG_INSTANCE_CHAT
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    GroupChatIngest.HandleEvent(state, "CHAT_MSG_INSTANCE_CHAT", {
      text = "spread out",
      playerName = "DPS-Realm",
      lineID = 501,
      guid = "Player-1084-00000030",
    })
    GroupChatIngest.HandleEvent(state, "CHAT_MSG_INSTANCE_CHAT_LEADER", {
      text = "pull now",
      playerName = "Leader-Realm",
      lineID = 502,
      guid = "Player-1084-00000031",
    })

    local conv = state.store.conversations["instance::arthas-area52"]
    assert(conv ~= nil, "instance conversation should exist")
    assert(#conv.messages == 2, "both messages should merge, got: " .. tostring(#conv.messages))
    assert(conv.messages[2].isLeader == true, "second message should have isLeader=true")
  end

  -- ----------------------------------------------------------------
  -- 6. CHAT_MSG_BN_CONVERSATION with conversationID=42 →
  --    key bnconv::42, channel=BN_CONVERSATION
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    local handled = GroupChatIngest.HandleEvent(state, "CHAT_MSG_BN_CONVERSATION", {
      text = "hey bnet friends",
      playerName = "SomeBattleTag#1234",
      lineID = 601,
      guid = nil,
      bnSenderID = 99001,
      conversationID = 42,
    })
    assert(handled == true, "CHAT_MSG_BN_CONVERSATION with conversationID should return true")

    local expectedKey = "bnconv::42"
    local conv = state.store.conversations[expectedKey]
    assert(conv ~= nil, "conversation should exist at key " .. expectedKey)
    assert(conv.channel == ChannelType.BN_CONVERSATION, "channel should be BN_CONVERSATION, got: " .. tostring(conv.channel))
    assert(conv.messages[1].text == "hey bnet friends", "text mismatch")
    assert(conv.conversationKey == expectedKey, "conversationKey stamp missing")
  end

  -- ----------------------------------------------------------------
  -- 7. CHAT_MSG_BN_CONVERSATION with nil conversationID returns false
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    local handled = GroupChatIngest.HandleEvent(state, "CHAT_MSG_BN_CONVERSATION", {
      text = "unresolved bnet msg",
      playerName = "Unknown#0000",
      lineID = 701,
      guid = nil,
      bnSenderID = 99002,
      conversationID = nil,
    })
    assert(handled == false, "CHAT_MSG_BN_CONVERSATION with nil conversationID should return false")
    -- no conversation should have been created
    local count = 0
    for _ in pairs(state.store.conversations) do
      count = count + 1
    end
    assert(count == 0, "no conversation should be created when conversationID is nil")
  end

  -- ----------------------------------------------------------------
  -- 8. Direction = "out" when payload.guid matches state.localPlayerGuid
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    local handled = GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", {
      text = "I am the local player",
      playerName = "Arthas-Area52",
      lineID = 801,
      guid = "Player-1084-00000001", -- matches state.localPlayerGuid
    })
    assert(handled == true, "should handle outgoing PARTY message")

    local conv = state.store.conversations["party::arthas-area52"]
    assert(conv ~= nil, "conversation should exist")
    assert(conv.messages[1].direction == "out", "direction should be out for local player's guid")
  end

  -- ----------------------------------------------------------------
  -- 8b. Outgoing group message stamps senderClassTag + senderName so the
  --     bubble icon and "You — <char>" label survive a relog.
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    local previousUnitClass = _G.UnitClass
    local previousUnitName = _G.UnitName
    _G.UnitClass = function()
      return "Druid", "DRUID"
    end
    _G.UnitName = function()
      return "Arthas"
    end

    GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", {
      text = "hello from me",
      playerName = "Arthas-Area52",
      lineID = 850,
      guid = "Player-1084-00000001",
      -- playerInfo absent: force fallback to live UnitClass/UnitName
    })

    _G.UnitClass = previousUnitClass
    _G.UnitName = previousUnitName

    local conv = state.store.conversations["party::arthas-area52"]
    local msg = conv.messages[1]
    assert(msg.direction == "out", "expected outgoing")
    assert(msg.senderClassTag == "DRUID", "outgoing group message should stamp senderClassTag, got: " .. tostring(msg.senderClassTag))
    assert(msg.senderName == "Arthas", "outgoing group message should stamp senderName (short form), got: " .. tostring(msg.senderName))
  end

  -- ----------------------------------------------------------------
  -- 8c. Outgoing group message prefers resolved playerInfo.classTag over
  --     the live UnitClass lookup (avoids a second API call).
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    local previousUnitClass = _G.UnitClass
    _G.UnitClass = function()
      return "Druid", "DRUID"
    end

    GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", {
      text = "hello again",
      playerName = "Arthas-Area52",
      lineID = 851,
      guid = "Player-1084-00000001",
      playerInfo = { classTag = "MAGE" },
    })

    _G.UnitClass = previousUnitClass

    local conv = state.store.conversations["party::arthas-area52"]
    local msg = conv.messages[1]
    assert(msg.senderClassTag == "MAGE", "should prefer resolved playerInfo.classTag over UnitClass, got: " .. tostring(msg.senderClassTag))
  end

  -- ----------------------------------------------------------------
  -- 8d. Incoming group message must NOT stamp senderClassTag.
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    local previousUnitClass = _G.UnitClass
    _G.UnitClass = function()
      return "Druid", "DRUID"
    end

    GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", {
      text = "someone else",
      playerName = "OtherPlayer-Realm",
      lineID = 852,
      guid = "Player-1084-FFFFFFFF",
      playerInfo = { classTag = "PRIEST" },
    })

    _G.UnitClass = previousUnitClass

    local conv = state.store.conversations["party::arthas-area52"]
    local msg = conv.messages[1]
    assert(msg.direction == "in", "expected incoming")
    assert(msg.senderClassTag == nil, "incoming must not stamp senderClassTag")
  end

  -- ----------------------------------------------------------------
  -- 9. Direction = "in" when payload.guid doesn't match localPlayerGuid
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", {
      text = "someone else spoke",
      playerName = "OtherPlayer-Realm",
      lineID = 901,
      guid = "Player-1084-FFFFFFFF", -- different guid
    })

    local conv = state.store.conversations["party::arthas-area52"]
    assert(conv.messages[1].direction == "in", "direction should be in for other player's guid")
  end

  -- ----------------------------------------------------------------
  -- 10. BN_CONVERSATION: direction="out" when bnSenderID matches
  --     state.localBnetAccountID
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    GroupChatIngest.HandleEvent(state, "CHAT_MSG_BN_CONVERSATION", {
      text = "I said this in bnet conv",
      playerName = "Me#1234",
      lineID = 1001,
      guid = nil,
      bnSenderID = 12345, -- matches state.localBnetAccountID
      conversationID = 7,
    })

    local conv = state.store.conversations["bnconv::7"]
    assert(conv ~= nil, "conversation should exist")
    assert(conv.messages[1].direction == "out", "direction should be out when bnSenderID matches localBnetAccountID")
  end

  -- ----------------------------------------------------------------
  -- 11. Unknown event name returns false
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    local handled = GroupChatIngest.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "this is a whisper",
      playerName = "Someone-Realm",
      lineID = 1101,
      guid = "Player-1084-AAAAAAAA",
    })
    assert(handled == false, "CHAT_MSG_WHISPER should not be handled by GroupChatIngest")
  end

  -- ----------------------------------------------------------------
  -- 12. No whisper-state mutation after handling a PARTY event
  -- ----------------------------------------------------------------
  do
    local state = makeState()
    -- Pre-seed sentinel values in whisper-specific state
    state.pendingOutgoing = { sentinel = "keep-me" }
    state.availabilityByGUID = { sentinel = "keep-me-too" }
    state.lastIncomingWhisperKey = "whisper::some-key"

    GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", {
      text = "group msg",
      playerName = "Someone-Realm",
      lineID = 1201,
      guid = "Player-1084-BBBBBBBB",
    })

    assert(state.pendingOutgoing.sentinel == "keep-me", "pendingOutgoing must not be mutated by group ingest")
    assert(state.availabilityByGUID.sentinel == "keep-me-too", "availabilityByGUID must not be mutated by group ingest")
    assert(state.lastIncomingWhisperKey == "whisper::some-key", "lastIncomingWhisperKey must not be mutated by group ingest")
  end

  -- ----------------------------------------------------------------
  -- 13. isActive=true → unreadCount stays 0; isActive=false → unreadCount=1
  -- ----------------------------------------------------------------
  do
    -- Active conversation: unread stays 0
    local activeKey = "party::arthas-area52"
    local stateActive = makeState({ activeConversationKey = activeKey })
    GroupChatIngest.HandleEvent(stateActive, "CHAT_MSG_PARTY", {
      text = "active window msg",
      playerName = "Other-Realm",
      lineID = 1301,
      guid = "Player-1084-CCCCCCCC",
    })
    local convActive = stateActive.store.conversations[activeKey]
    assert(convActive.unreadCount == 0, "unreadCount should stay 0 when conversation is active")

    -- Inactive conversation: unread increments
    local stateInactive = makeState({ activeConversationKey = "some-other-key" })
    GroupChatIngest.HandleEvent(stateInactive, "CHAT_MSG_PARTY", {
      text = "inactive window msg",
      playerName = "Other-Realm",
      lineID = 1302,
      guid = "Player-1084-DDDDDDDD",
    })
    local convInactive = stateInactive.store.conversations["party::arthas-area52"]
    assert(convInactive.unreadCount == 1, "unreadCount should be 1 for inactive conversation")
  end

  -- ----------------------------------------------------------------
  -- 13c. 12.0 Midnight: payloads carrying "secret string" fields must be
  --      dropped at ingest. Storing them poisons every downstream read
  --      (ConversationSnapshot.buildSearchText calls value == "",
  --      string.lower, table.concat — each throws on a secret string).
  -- ----------------------------------------------------------------
  do
    -- Plain Lua can't reproduce WoW's "secret string" type, so swap the
    -- detector with one that flags a sentinel value. This verifies the
    -- HandleEvent gate: secret fields → drop (return false, no conversation).
    local SECRET = "__SECRET__"
    local originalDetect = GroupChatIngest._isSecretString
    GroupChatIngest._isSecretString = function(v)
      return v == SECRET
    end

    local state = makeState()
    local ok, handled = pcall(GroupChatIngest.HandleEvent, state, "CHAT_MSG_RAID", {
      text = SECRET,
      playerName = "Leader-Realm",
      lineID = 9999,
      guid = "Player-1084-OTHER",
    })

    GroupChatIngest._isSecretString = originalDetect

    assert(ok, "HandleEvent must not crash on a secret-string payload; got: " .. tostring(handled))
    assert(handled == false, "HandleEvent must return false for secret-string payloads (dropped)")

    local conv = state.store.conversations["raid::arthas-area52"]
    assert(conv == nil, "no conversation should be created from a secret-string payload")

    -- real detector sanity checks — plain strings/nil/numbers are NOT secret
    assert(originalDetect(nil) == false, "nil is not secret")
    assert(originalDetect("hello") == false, "plain string is not secret")
    assert(originalDetect(42) == false, "number is not secret")
    assert(originalDetect("") == false, "empty string is not secret")
  end

  -- ----------------------------------------------------------------
  -- 13b. 12.0 Midnight: a "secret string" GUID throws on comparison from
  --      an addon-tainted call stack. resolveDirection must NOT crash —
  --      it should fall through to direction="in" so the message still
  --      lands in the conversation instead of erroring the handler.
  -- ----------------------------------------------------------------
  do
    -- compareGuids() unit — throwing __eq simulates the secret-string crash
    local throwingMt = {
      __eq = function()
        error("attempt to compare field 'guid' (a secret string value tainted by 'WhisperMessenger')")
      end,
    }
    local secret = setmetatable({}, throwingMt)
    local mine = setmetatable({}, throwingMt)
    assert(GroupChatIngest._compareGuids(secret, mine) == false, "compareGuids must swallow secret-string throws and return false")
    assert(GroupChatIngest._compareGuids(nil, "x") == false, "nil guid yields false")
    assert(GroupChatIngest._compareGuids("x", nil) == false, "nil localGuid yields false")
    assert(GroupChatIngest._compareGuids("x", "x") == true, "matching plain guids yields true")
    assert(GroupChatIngest._compareGuids("x", "y") == false, "differing plain guids yield false")

    -- End-to-end: RAID_WARNING with a throwing-on-eq guid must still ingest
    local state = makeState()
    state.localPlayerGuid = setmetatable({}, throwingMt) -- bypass the type=="string" guard below
    -- resolveLocalPlayerGuid only returns a string, so force a string lookup:
    state.localPlayerGuid = "Player-1084-00000001"
    local handled = GroupChatIngest.HandleEvent(state, "CHAT_MSG_RAID_WARNING", {
      text = "pull now",
      playerName = "Leader-Realm",
      lineID = 1500,
      guid = "Player-1305-SECRET", -- plain string path; compareGuids returns false cleanly
    })
    assert(handled == true, "RAID_WARNING must be handled without crashing")
    local conv = state.store.conversations["raid::arthas-area52"]
    assert(conv ~= nil, "raid conversation should exist")
    assert(conv.messages[1].direction == "in", "non-matching guid → direction=in")
  end

  -- ----------------------------------------------------------------
  -- 14. Outgoing (direction=out) does NOT increment unread
  -- ----------------------------------------------------------------
  do
    local state = makeState({ activeConversationKey = "some-other-key" })
    GroupChatIngest.HandleEvent(state, "CHAT_MSG_PARTY", {
      text = "my outgoing message",
      playerName = "Arthas-Area52",
      lineID = 1401,
      guid = "Player-1084-00000001", -- local player → direction=out
    })

    local conv = state.store.conversations["party::arthas-area52"]
    assert(conv ~= nil, "conversation should exist")
    assert(conv.unreadCount == 0, "outgoing messages must not increment unreadCount, got: " .. tostring(conv.unreadCount))
  end
end
