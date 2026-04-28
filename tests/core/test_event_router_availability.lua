local Store = require("WhisperMessenger.Model.ConversationStore")
local Queue = require("WhisperMessenger.Model.LockdownQueue")
local Router = require("WhisperMessenger.Core.EventRouter")

return function()
  local function makeState()
    return {
      localProfileId = "me",
      store = Store.New({ maxMessagesPerConversation = 10 }),
      queue = Queue.New(),
      activeConversationKey = nil,
      availabilityByGUID = {},
      pendingOutgoing = {},
      now = function()
        return 1000
      end,
      isChatMessagingLocked = function()
        return false
      end,
    }
  end

  -- Incoming WoW whisper sets availability to CanWhisper
  do
    local state = makeState()
    -- Simulate stale WrongFaction in cache
    state.availabilityByGUID["Player-1084-0A7E2D88"] = { status = "WrongFaction", canWhisper = false }

    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "hello",
      playerName = "Holyoverdisc-TarrenMill",
      lineID = 201,
      guid = "Player-1084-0A7E2D88",
    })

    local avail = state.availabilityByGUID["Player-1084-0A7E2D88"]
    assert(avail ~= nil, "availability should be set after incoming whisper")
    assert(avail.status == "CanWhisper", "incoming whisper should set status to CanWhisper, got: " .. tostring(avail.status))
    assert(avail.canWhisper == true, "incoming whisper should set canWhisper=true")
  end

  -- Outgoing WoW whisper confirm sets availability to CanWhisper
  do
    local state = makeState()
    state.availabilityByGUID["Player-1305-0D663D88"] = { status = "WrongFaction", canWhisper = false }

    Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", {
      text = "hey",
      playerName = "Ferdifreak-Kazzak",
      lineID = 202,
      guid = "Player-1305-0D663D88",
    })

    local avail = state.availabilityByGUID["Player-1305-0D663D88"]
    assert(avail ~= nil, "availability should be set after outgoing whisper")
    assert(avail.status == "CanWhisper", "outgoing whisper confirm should set status to CanWhisper, got: " .. tostring(avail.status))
  end

  -- Outgoing whisper inform with short playerName still matches pending send by guid/name
  do
    local state = makeState()

    local pendingKey = Router.RecordPendingSend(state, {
      channel = "WOW",
      displayName = "Arthas-Area52",
      guid = "Player-3676-0ABCDEF0",
    }, "hello")

    local _, meta = Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", {
      text = "hello",
      playerName = "Arthas",
      lineID = 2021,
      guid = "Player-3676-0ABCDEF0",
    })

    assert(meta ~= nil and meta.outgoingFromPendingSend == true, "pending send should be matched for outgoing inform")
    local pending = state.pendingOutgoing[pendingKey]
    assert(pending ~= nil and #pending == 0, "matched pending send should be consumed")
  end

  -- Stale pending sends are pruned during outgoing inform processing
  do
    local state = makeState()
    state.pendingOutgoing["wow::WOW::stale"] = {
      {
        text = "old",
        createdAt = 900,
        channel = "WOW",
        guid = "Player-3676-0STALE000",
        displayName = "Stale-Area52",
      },
    }

    local _, meta = Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", {
      text = "fresh",
      playerName = "Jaina-Proudmoore",
      lineID = 2022,
      guid = "Player-3676-0FRESH000",
    })

    assert(meta ~= nil and meta.outgoingFromPendingSend == false, "fresh outgoing inform should not match stale pending send")
    local staleQueue = state.pendingOutgoing["wow::WOW::stale"]
    assert(staleQueue ~= nil and #staleQueue == 0, "stale pending sends should be pruned")
  end

  -- Incoming BNet whisper sets availability for GUID if available
  do
    local state = makeState()

    Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", {
      text = "yo",
      playerName = "Giannis",
      lineID = 203,
      guid = "Player-1305-0D65D962",
      channel = "BN",
      bnetAccountID = 16,
      accountInfo = { battleTag = "Giannis#2964" },
    })

    local avail = state.availabilityByGUID["Player-1305-0D65D962"]
    assert(avail ~= nil, "BNet whisper with GUID should set availability")
    assert(avail.status == "CanWhisper", "BNet whisper should set status to CanWhisper, got: " .. tostring(avail.status))
  end

  -- Incoming whisper without GUID does not crash
  do
    local state = makeState()

    Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", {
      text = "test",
      playerName = "Friend",
      lineID = 204,
      guid = nil,
      channel = "BN",
      bnetAccountID = 99,
      accountInfo = { battleTag = "Friend#1111" },
    })

    -- No GUID, so no availability entry — just verify no crash
    assert(true, "should not crash when guid is nil")
  end

  -- Availability not set when event has no guid and contact has no guid
  do
    local state = makeState()

    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "hi",
      playerName = "Unknown-Realm",
      lineID = 205,
      guid = nil,
    })

    -- No guid anywhere, availabilityByGUID should be empty
    local count = 0
    for _ in pairs(state.availabilityByGUID) do
      count = count + 1
    end
    assert(count == 0, "no availability should be set without a guid")
  end

  -- CHAT_MSG_BN_WHISPER creates message with battleTag from accountInfo
  do
    local state = makeState()

    Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", {
      text = "hello",
      playerName = "Giannis",
      lineID = 206,
      guid = "Player-1305-0D65D963",
      channel = "BN",
      bnetAccountID = 20,
      accountInfo = { battleTag = "Giannis#2964" },
    })

    local convKey = nil
    for k, _ in pairs(state.store.conversations) do
      convKey = k
    end
    assert(convKey ~= nil, "conversation should be created")
    local conv = state.store.conversations[convKey]
    local msg = conv.messages[1]
    assert(msg.battleTag == "Giannis#2964", "message battleTag should be set from accountInfo, got: " .. tostring(msg.battleTag))
  end

  -- Outgoing whisper clears unread count (replying means user saw the conversation)
  do
    local state = makeState()

    -- First, receive an incoming whisper to create unread
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "hey there",
      playerName = "Thrall-Draenor",
      lineID = 301,
      guid = "Player-1403-0ABCDEF0",
    })

    local key = "wow::WOW::thrall-draenor"
    local conv = state.store.conversations[key]
    assert(conv ~= nil, "conversation should exist after incoming whisper")
    assert(conv.unreadCount == 1, "should have 1 unread after incoming whisper, got: " .. tostring(conv.unreadCount))

    -- Now reply via WoW chat
    Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", {
      text = "hey!",
      playerName = "Thrall-Draenor",
      lineID = 302,
      guid = "Player-1403-0ABCDEF0",
    })

    assert(conv.unreadCount == 0, "replying should clear unread count, got: " .. tostring(conv.unreadCount))
  end

  -- Outgoing whisper stamps senderClassTag from the current player's class so
  -- the bubble icon survives a relog to another character.
  do
    local state = makeState()
    local previousUnitClass = _G.UnitClass
    _G.UnitClass = function()
      return "Priest", "PRIEST"
    end

    Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", {
      text = "hi",
      playerName = "Sylvanas-Silvermoon",
      lineID = 401,
      guid = "Player-1084-0D00D0DE",
    })

    _G.UnitClass = previousUnitClass

    local convKey = "wow::WOW::sylvanas-silvermoon"
    local conv = state.store.conversations[convKey]
    assert(conv ~= nil, "outgoing whisper conversation should exist")
    local msg = conv.messages[1]
    assert(msg ~= nil and msg.direction == "out", "expected outgoing message in conversation")
    assert(msg.senderClassTag == "PRIEST", "outgoing message should stamp senderClassTag, got: " .. tostring(msg.senderClassTag))
  end

  -- Outgoing whisper stamps senderName with the local player's short name
  -- so the "You — <char>" label can render after relog.
  do
    local state = makeState()
    local previousUnitClass = _G.UnitClass
    local previousUnitName = _G.UnitName
    _G.UnitClass = function()
      return "Priest", "PRIEST"
    end
    _G.UnitName = function()
      return "Jaina"
    end

    Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", {
      text = "hi",
      playerName = "Thrall-Draenor",
      lineID = 410,
      guid = "Player-1084-0D00D0E0",
    })

    _G.UnitClass = previousUnitClass
    _G.UnitName = previousUnitName

    local conv = state.store.conversations["wow::WOW::thrall-draenor"]
    local msg = conv.messages[1]
    assert(msg.senderName == "Jaina", "outgoing message should stamp senderName, got: " .. tostring(msg.senderName))
  end

  -- Incoming whispers must NOT stamp senderClassTag — that would overwrite
  -- the sender's class with our own on redisplay.
  do
    local state = makeState()
    local previousUnitClass = _G.UnitClass
    _G.UnitClass = function()
      return "Priest", "PRIEST"
    end

    Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
      text = "hey",
      playerName = "Jaina-Proudmoore",
      lineID = 402,
      guid = "Player-3676-0ABC1234",
    })

    _G.UnitClass = previousUnitClass

    local convKey = "wow::WOW::jaina-proudmoore"
    local conv = state.store.conversations[convKey]
    local msg = conv.messages[1]
    assert(msg.direction == "in", "expected incoming message")
    assert(msg.senderClassTag == nil, "incoming message must not stamp senderClassTag")
  end

  -- CAN_LOCAL_WHISPER_TARGET_RESPONSE fires onAvailabilityChanged hook on status change
  do
    local state = makeState()
    local hookCalls = {}
    state.onAvailabilityChanged = function(guid)
      table.insert(hookCalls, guid)
    end

    -- First response establishes initial status → hook fires
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", {
      guid = "Player-1084-0ABC0001",
      status = "CanWhisper",
      rawStatus = 0,
    })
    assert(#hookCalls == 1, "hook should fire on first response, got: " .. tostring(#hookCalls))
    assert(hookCalls[1] == "Player-1084-0ABC0001", "hook should receive guid")

    -- Repeat response with identical status → hook should NOT re-fire
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", {
      guid = "Player-1084-0ABC0001",
      status = "CanWhisper",
      rawStatus = 0,
    })
    assert(#hookCalls == 1, "hook should not re-fire on identical status, got: " .. tostring(#hookCalls))

    -- Status flip → hook fires again
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", {
      guid = "Player-1084-0ABC0001",
      status = "Offline",
      rawStatus = 1,
    })
    assert(#hookCalls == 2, "hook should fire on status change, got: " .. tostring(#hookCalls))
    assert(hookCalls[2] == "Player-1084-0ABC0001", "hook should receive guid on change")
  end

  -- confirmedByWhisper guard short-circuits BEFORE hook fires
  do
    local state = makeState()
    local hookCalls = {}
    state.onAvailabilityChanged = function(guid)
      table.insert(hookCalls, guid)
    end
    state.availabilityByGUID["Player-1084-0ABC0002"] = {
      status = "CanWhisper",
      canWhisper = true,
      confirmedByWhisper = true,
    }

    -- Async API returns WrongFaction, but we keep confirmedByWhisper state
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", {
      guid = "Player-1084-0ABC0002",
      status = "WrongFaction",
      rawStatus = 2,
    })

    assert(#hookCalls == 0, "hook must not fire when confirmedByWhisper guard keeps existing state")
  end

  -- Hook absence does not crash the router
  do
    local state = makeState()
    state.onAvailabilityChanged = nil

    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", {
      guid = "Player-1084-0ABC0003",
      status = "CanWhisper",
      rawStatus = 0,
    })

    local avail = state.availabilityByGUID["Player-1084-0ABC0003"]
    assert(avail ~= nil and avail.status == "CanWhisper", "availability should still be stored without hook")
  end

  -- BNet outgoing whisper also clears unread count
  do
    local state = makeState()

    Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", {
      text = "hello",
      playerName = "Friend",
      lineID = 303,
      guid = nil,
      channel = "BN",
      bnetAccountID = 50,
      accountInfo = { battleTag = "Friend#9999" },
    })

    local convKey = nil
    for k, _ in pairs(state.store.conversations) do
      if k:find("friend#9999") then
        convKey = k
      end
    end
    assert(convKey ~= nil, "BNet conversation should exist")
    local conv = state.store.conversations[convKey]
    assert(conv.unreadCount == 1, "should have 1 unread after BNet incoming")

    Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER_INFORM", {
      text = "hi back",
      playerName = "Friend",
      lineID = 304,
      guid = nil,
      channel = "BN",
      bnetAccountID = 50,
      accountInfo = { battleTag = "Friend#9999" },
    })

    assert(conv.unreadCount == 0, "BNet reply should clear unread count, got: " .. tostring(conv.unreadCount))
  end
end
