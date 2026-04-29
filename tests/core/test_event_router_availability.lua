-- Comprehensive Router.HandleEvent regression tests.
--
-- Despite the filename, this file owns the full event pipeline:
--   * availability cache (CHAT_MSG_WHISPER, CHAT_MSG_WHISPER_INFORM, CHAT_MSG_BN_WHISPER)
--   * pending outgoing matching + stale prune
--   * message field stamping (battleTag, senderClassTag, senderName)
--   * unread clear on outgoing reply (channel-agnostic)
--   * CAN_LOCAL_WHISPER_TARGET_RESPONSE hook + confirmedByWhisper guard

local Store = require("WhisperMessenger.Model.ConversationStore")
local Queue = require("WhisperMessenger.Model.LockdownQueue")
local Router = require("WhisperMessenger.Core.EventRouter")

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

local function whisperEvent(over)
  local e = {
    text = "hello",
    playerName = "Holyoverdisc-TarrenMill",
    lineID = 201,
    guid = "Player-1084-0A7E2D88",
  }
  for k, v in pairs(over or {}) do
    e[k] = v
  end
  return e
end

local function bnetEvent(over)
  local e = {
    text = "hello",
    playerName = "Friend",
    lineID = 203,
    guid = nil,
    channel = "BN",
    bnetAccountID = 50,
    accountInfo = { battleTag = "Friend#9999" },
  }
  for k, v in pairs(over or {}) do
    e[k] = v
  end
  return e
end

local function withPlayer(class, name, fn)
  local prevClass = _G.UnitClass
  local prevName = _G.UnitName
  _G.UnitClass = function()
    return class, class:upper()
  end
  if name then
    _G.UnitName = function()
      return name
    end
  end
  fn()
  _G.UnitClass = prevClass
  _G.UnitName = prevName
end

return function()
  -- ===== Availability cache =====

  -- Incoming WoW whisper sets availability to CanWhisper, overriding stale state.
  do
    local state = makeState()
    state.availabilityByGUID["Player-1084-0A7E2D88"] = { status = "WrongFaction", canWhisper = false }
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent())
    local avail = state.availabilityByGUID["Player-1084-0A7E2D88"]
    assert(avail and avail.status == "CanWhisper", "incoming whisper should refresh status to CanWhisper")
    assert(avail.canWhisper == true, "incoming whisper should set canWhisper=true")
  end

  -- Outgoing WoW whisper inform sets availability to CanWhisper.
  do
    local state = makeState()
    state.availabilityByGUID["Player-1305-0D663D88"] = { status = "WrongFaction", canWhisper = false }
    Router.HandleEvent(
      state,
      "CHAT_MSG_WHISPER_INFORM",
      whisperEvent({
        playerName = "Ferdifreak-Kazzak",
        lineID = 202,
        guid = "Player-1305-0D663D88",
      })
    )
    local avail = state.availabilityByGUID["Player-1305-0D663D88"]
    assert(avail and avail.status == "CanWhisper", "outgoing inform should set status to CanWhisper")
  end

  -- Incoming BNet whisper with a GUID sets availability for that GUID.
  do
    local state = makeState()
    Router.HandleEvent(
      state,
      "CHAT_MSG_BN_WHISPER",
      bnetEvent({ guid = "Player-1305-0D65D962", playerName = "Giannis", bnetAccountID = 16, accountInfo = { battleTag = "Giannis#2964" } })
    )
    local avail = state.availabilityByGUID["Player-1305-0D65D962"]
    assert(avail and avail.status == "CanWhisper", "BNet whisper with guid should set CanWhisper")
  end

  -- Whisper without a GUID stores nothing in the availability cache and does
  -- not crash. Covers both the BNet and WoW cases.
  for _, scenario in ipairs({
    {
      event = "CHAT_MSG_BN_WHISPER",
      payload = {
        text = "test",
        playerName = "Friend",
        lineID = 204,
        channel = "BN",
        bnetAccountID = 99,
        accountInfo = { battleTag = "Friend#1111" },
      },
    },
    {
      event = "CHAT_MSG_WHISPER",
      payload = { text = "hi", playerName = "Unknown-Realm", lineID = 205 },
    },
  }) do
    local state = makeState()
    Router.HandleEvent(state, scenario.event, scenario.payload)
    local count = 0
    for _ in pairs(state.availabilityByGUID) do
      count = count + 1
    end
    assert(count == 0, "no availability should be cached without a guid (" .. scenario.event .. ")")
  end

  -- ===== Pending outgoing matching =====

  -- Outgoing inform with a short playerName still matches a pending send by guid.
  do
    local state = makeState()
    local pendingKey = Router.RecordPendingSend(state, {
      channel = "WOW",
      displayName = "Arthas-Area52",
      guid = "Player-3676-0ABCDEF0",
    }, "hello")

    local _, meta = Router.HandleEvent(
      state,
      "CHAT_MSG_WHISPER_INFORM",
      whisperEvent({
        playerName = "Arthas",
        lineID = 2021,
        guid = "Player-3676-0ABCDEF0",
      })
    )
    assert(meta and meta.outgoingFromPendingSend == true, "outgoing inform should match the pending send")
    assert(state.pendingOutgoing[pendingKey] and #state.pendingOutgoing[pendingKey] == 0, "matched pending send should be consumed")
  end

  -- A fresh outgoing inform that doesn't correspond to any pending entry
  -- prunes stale ones rather than matching them.
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
    local _, meta = Router.HandleEvent(
      state,
      "CHAT_MSG_WHISPER_INFORM",
      whisperEvent({
        text = "fresh",
        playerName = "Jaina-Proudmoore",
        lineID = 2022,
        guid = "Player-3676-0FRESH000",
      })
    )
    assert(meta and meta.outgoingFromPendingSend == false, "fresh inform should not match stale pending send")
    assert(#state.pendingOutgoing["wow::WOW::stale"] == 0, "stale pending sends should be pruned")
  end

  -- ===== Message field stamping =====

  -- Incoming BNet whisper records battleTag from accountInfo on the message.
  do
    local state = makeState()
    Router.HandleEvent(
      state,
      "CHAT_MSG_BN_WHISPER",
      bnetEvent({ guid = "Player-1305-0D65D963", playerName = "Giannis", bnetAccountID = 20, accountInfo = { battleTag = "Giannis#2964" } })
    )
    local convKey
    for k in pairs(state.store.conversations) do
      convKey = k
    end
    assert(convKey, "BNet incoming whisper should create a conversation")
    assert(state.store.conversations[convKey].messages[1].battleTag == "Giannis#2964", "message should record battleTag from accountInfo")
  end

  -- Outgoing whisper stamps senderClassTag with the local player's class so
  -- the bubble icon survives a relog to a different character.
  do
    local state = makeState()
    withPlayer("Priest", nil, function()
      Router.HandleEvent(
        state,
        "CHAT_MSG_WHISPER_INFORM",
        whisperEvent({
          playerName = "Sylvanas-Silvermoon",
          lineID = 401,
          guid = "Player-1084-0D00D0DE",
        })
      )
    end)
    local conv = state.store.conversations["wow::WOW::sylvanas-silvermoon"]
    local msg = conv and conv.messages[1]
    assert(msg and msg.direction == "out", "expected an outgoing message in the conversation")
    assert(msg.senderClassTag == "PRIEST", "outgoing message should stamp senderClassTag, got " .. tostring(msg.senderClassTag))
  end

  -- Outgoing whisper stamps senderName with the local short name so "You — <char>"
  -- can render after relog.
  do
    local state = makeState()
    withPlayer("Priest", "Jaina", function()
      Router.HandleEvent(
        state,
        "CHAT_MSG_WHISPER_INFORM",
        whisperEvent({
          playerName = "Thrall-Draenor",
          lineID = 410,
          guid = "Player-1084-0D00D0E0",
        })
      )
    end)
    local msg = state.store.conversations["wow::WOW::thrall-draenor"].messages[1]
    assert(msg.senderName == "Jaina", "outgoing message should stamp senderName, got " .. tostring(msg.senderName))
  end

  -- Incoming whispers must NOT stamp senderClassTag - that would overwrite
  -- the sender's class with our own when redisplayed.
  do
    local state = makeState()
    withPlayer("Priest", nil, function()
      Router.HandleEvent(
        state,
        "CHAT_MSG_WHISPER",
        whisperEvent({
          playerName = "Jaina-Proudmoore",
          lineID = 402,
          guid = "Player-3676-0ABC1234",
        })
      )
    end)
    local msg = state.store.conversations["wow::WOW::jaina-proudmoore"].messages[1]
    assert(msg.direction == "in", "expected incoming direction")
    assert(msg.senderClassTag == nil, "incoming message must not stamp senderClassTag")
  end

  -- ===== Unread clear on outgoing reply (channel-agnostic) =====

  -- Replying to an incoming whisper clears unread - same behavior on WoW and BNet.
  for _, scenario in ipairs({
    {
      label = "WoW",
      receive = function(state)
        Router.HandleEvent(
          state,
          "CHAT_MSG_WHISPER",
          whisperEvent({
            text = "hey there",
            playerName = "Thrall-Draenor",
            lineID = 301,
            guid = "Player-1403-0ABCDEF0",
          })
        )
        return "wow::WOW::thrall-draenor"
      end,
      reply = function(state)
        Router.HandleEvent(
          state,
          "CHAT_MSG_WHISPER_INFORM",
          whisperEvent({
            text = "hey!",
            playerName = "Thrall-Draenor",
            lineID = 302,
            guid = "Player-1403-0ABCDEF0",
          })
        )
      end,
    },
    {
      label = "BNet",
      receive = function(state)
        Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", bnetEvent({ playerName = "Friend", lineID = 303, bnetAccountID = 50 }))
        for k in pairs(state.store.conversations) do
          if k:find("friend#9999") then
            return k
          end
        end
        return nil
      end,
      reply = function(state)
        Router.HandleEvent(
          state,
          "CHAT_MSG_BN_WHISPER_INFORM",
          bnetEvent({ text = "hi back", playerName = "Friend", lineID = 304, bnetAccountID = 50 })
        )
      end,
    },
  }) do
    local state = makeState()
    local convKey = scenario.receive(state)
    assert(convKey, scenario.label .. ": conversation key should exist after incoming")
    local conv = state.store.conversations[convKey]
    assert(conv and conv.unreadCount == 1, scenario.label .. ": expected unreadCount=1 after incoming, got " .. tostring(conv and conv.unreadCount))
    scenario.reply(state)
    assert(conv.unreadCount == 0, scenario.label .. ": replying should clear unread, got " .. tostring(conv.unreadCount))
  end

  -- ===== CAN_LOCAL_WHISPER_TARGET_RESPONSE hook =====

  -- Initial response fires the hook; an identical follow-up does not; a
  -- status flip fires it again.
  do
    local state = makeState()
    local hookCalls = {}
    state.onAvailabilityChanged = function(guid)
      hookCalls[#hookCalls + 1] = guid
    end
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", {
      guid = "Player-1084-0ABC0001",
      status = "CanWhisper",
      rawStatus = 0,
    })
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", {
      guid = "Player-1084-0ABC0001",
      status = "CanWhisper",
      rawStatus = 0,
    })
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", {
      guid = "Player-1084-0ABC0001",
      status = "Offline",
      rawStatus = 1,
    })
    assert(#hookCalls == 2, "hook should fire on first response and on status flip, got " .. #hookCalls)
    assert(hookCalls[1] == "Player-1084-0ABC0001", "hook should receive the guid")
    assert(hookCalls[2] == "Player-1084-0ABC0001", "hook should receive the guid on flip")
  end

  -- confirmedByWhisper guard short-circuits before the hook fires: the async
  -- API is allowed to disagree (WrongFaction) but we trust prior whisper traffic.
  do
    local state = makeState()
    local hookCalls = {}
    state.onAvailabilityChanged = function(guid)
      hookCalls[#hookCalls + 1] = guid
    end
    state.availabilityByGUID["Player-1084-0ABC0002"] = {
      status = "CanWhisper",
      canWhisper = true,
      confirmedByWhisper = true,
    }
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", {
      guid = "Player-1084-0ABC0002",
      status = "WrongFaction",
      rawStatus = 2,
    })
    assert(#hookCalls == 0, "hook must not fire when confirmedByWhisper guard preserves state")
  end

  -- Absence of the hook does not crash the router and availability is still cached.
  do
    local state = makeState()
    state.onAvailabilityChanged = nil
    Router.HandleEvent(state, "CAN_LOCAL_WHISPER_TARGET_RESPONSE", {
      guid = "Player-1084-0ABC0003",
      status = "CanWhisper",
      rawStatus = 0,
    })
    local avail = state.availabilityByGUID["Player-1084-0ABC0003"]
    assert(avail and avail.status == "CanWhisper", "availability should still be cached without a hook")
  end
end
