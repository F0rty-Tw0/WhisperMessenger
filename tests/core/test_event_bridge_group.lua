local Store = require("WhisperMessenger.Model.ConversationStore")
local ChannelType = require("WhisperMessenger.Model.Identity.ChannelType")

-- Stub dependencies so EventBridge loads cleanly
local EventBridge
do
  package.preload["WhisperMessenger.Transport.BNetResolver"] = function()
    return {
      NormalizeAvailabilityStatus = function(s)
        return s
      end,
      ResolveAccountInfo = function()
        return nil
      end,
      ResolvePlayerInfo = function()
        return {}
      end,
    }
  end
  package.preload["WhisperMessenger.Core.SoundPlayer"] = function()
    return { Play = function() end }
  end
  EventBridge = require("WhisperMessenger.Core.Bootstrap.EventBridge")
end

return function()
  local function makeRuntime(overrides)
    overrides = overrides or {}
    local r = {
      localProfileId = "arthas-area52",
      localPlayerGuid = "Player-1084-00000001",
      localBnetAccountID = 77777,
      store = Store.New({ maxMessagesPerConversation = 50 }),
      activeConversationKey = nil,
      pendingOutgoing = {},
      availabilityByGUID = {},
      lastIncomingWhisperKey = nil,
    }
    for k, v in pairs(overrides) do
      r[k] = v
    end
    return r
  end

  -- ----------------------------------------------------------------
  -- 1. RouteGroupEvent returns true for CHAT_MSG_PARTY
  -- ----------------------------------------------------------------
  do
    local runtime = makeRuntime()
    -- 17-arg signature: text, playerName, languageName, channelName,
    -- playerName2, specialFlags, zoneChannelID, channelIndex,
    -- channelBaseName, languageID, lineID, guid, bnSenderID
    local result = EventBridge.RouteGroupEvent(
      runtime,
      "CHAT_MSG_PARTY",
      "hello party", -- text
      "Thrall-Aggamaggan", -- playerName
      "", -- languageName
      "", -- channelName
      "", -- playerName2
      "", -- specialFlags
      0, -- zoneChannelID
      0, -- channelIndex
      "", -- channelBaseName
      0, -- languageID
      501, -- lineID
      "Player-1084-00000099" -- guid
      -- bnSenderID omitted (nil)
    )
    assert(result == true, "RouteGroupEvent should return true for CHAT_MSG_PARTY, got: " .. tostring(result))

    local conv = runtime.store.conversations["party::arthas-area52"]
    assert(conv ~= nil, "conversation should exist after routing PARTY event")
    assert(conv.channel == ChannelType.PARTY, "channel should be PARTY")
  end

  -- ----------------------------------------------------------------
  -- 2. RouteGroupEvent returns false for CHAT_MSG_WHISPER (pass-through)
  -- ----------------------------------------------------------------
  do
    local runtime = makeRuntime()
    local result =
      EventBridge.RouteGroupEvent(runtime, "CHAT_MSG_WHISPER", "hi there", "Someone-Realm", "", "", "", "", 0, 0, "", 0, 601, "Player-1084-AAAAAAAA")
    assert(result == false, "RouteGroupEvent should return false for CHAT_MSG_WHISPER, got: " .. tostring(result))
  end

  -- ----------------------------------------------------------------
  -- 3. RouteGroupEvent resolves conversationID for BN_CONVERSATION
  --    via stubbed BNGetNumConversations / BNGetConversationInfo
  -- ----------------------------------------------------------------
  do
    local runtime = makeRuntime()

    -- Stub BN conversation lookup globals: two conversations (55 and 56);
    -- the sender (presenceID 99001) is a member of conversation 56 only.
    local savedGetNum = _G.BNGetNumConversations
    local savedGetInfo = _G.BNGetConversationInfo
    local savedGetNumMembers = _G.BNGetNumConversationMembers
    local savedGetMemberInfo = _G.BNGetConversationMemberInfo
    _G.BNGetNumConversations = function()
      return 2
    end
    _G.BNGetConversationInfo = function(idx)
      if idx == 1 then
        return 55, "subject", 1
      elseif idx == 2 then
        return 56, "subject2", 1
      end
      return nil
    end
    _G.BNGetNumConversationMembers = function(_conversationID)
      return 1
    end
    _G.BNGetConversationMemberInfo = function(conversationID, _memberIndex)
      -- accountName, toonName, toonID, presenceID
      if conversationID == 56 then
        return "Battle#1234", "Char", 1, 99001
      end
      return "Other#5678", "Other", 2, 88002
    end

    local function routeBNMessage()
      return EventBridge.RouteGroupEvent(
        runtime,
        "CHAT_MSG_BN_CONVERSATION",
        "hey bnet", -- text
        "Battle#1234", -- playerName
        "", -- languageName
        "", -- channelName
        "", -- playerName2
        "", -- specialFlags
        0, -- zoneChannelID
        0, -- channelIndex
        "", -- channelBaseName
        0, -- languageID
        701, -- lineID
        nil, -- guid
        99001 -- bnSenderID
      )
    end

    local ok, result = pcall(routeBNMessage)
    assert(ok, "RouteGroupEvent for BN_CONVERSATION should not throw: " .. tostring(result))
    assert(result == true, "RouteGroupEvent should route the BN conversation message, got: " .. tostring(result))

    -- The message must land in the SENDER'S conversation (56), not the
    -- first conversation in the list (55).
    local foundKey
    for key in pairs(runtime.store.conversations) do
      foundKey = key
    end
    assert(foundKey ~= nil, "a BN conversation thread should exist")
    assert(string.find(foundKey, "56", 1, true) ~= nil, "message must be keyed to the sender's conversation 56; got key: " .. tostring(foundKey))
    assert(string.find(foundKey, "55", 1, true) == nil, "message must not be keyed to the first conversation 55; got key: " .. tostring(foundKey))

    -- Sender provably in NO conversation: filing into an arbitrary thread
    -- would corrupt histories, so the message is dropped.
    local absentRuntime = makeRuntime()
    local absentResult = EventBridge.RouteGroupEvent(
      absentRuntime,
      "CHAT_MSG_BN_CONVERSATION",
      "who am i",
      "Stranger#9999",
      "",
      "",
      "",
      "",
      0,
      0,
      "",
      0,
      703,
      nil,
      77123 -- presenceID not a member of conversation 55 or 56
    )
    assert(absentResult == false, "message from a sender in no known conversation is dropped; got: " .. tostring(absentResult))
    assert(next(absentRuntime.store.conversations) == nil, "no thread is created for an unmatched sender")

    -- Membership API missing entirely: fall back to the first conversation
    -- so the message is still captured rather than dropped.
    local fallbackRuntime = makeRuntime()
    _G.BNGetNumConversationMembers = nil
    _G.BNGetConversationMemberInfo = nil
    local fallbackOk, fallbackResult = pcall(function()
      return EventBridge.RouteGroupEvent(
        fallbackRuntime,
        "CHAT_MSG_BN_CONVERSATION",
        "hey again",
        "Battle#1234",
        "",
        "",
        "",
        "",
        0,
        0,
        "",
        0,
        702,
        nil,
        99001
      )
    end)
    assert(fallbackOk, "fallback routing should not throw: " .. tostring(fallbackResult))
    assert(fallbackResult == true, "fallback routing should still capture the message")
    local fallbackKey
    for key in pairs(fallbackRuntime.store.conversations) do
      fallbackKey = key
    end
    assert(
      fallbackKey and string.find(fallbackKey, "55", 1, true) ~= nil,
      "without membership APIs the first conversation is used; got key: " .. tostring(fallbackKey)
    )

    -- Restore globals
    _G.BNGetNumConversations = savedGetNum
    _G.BNGetConversationInfo = savedGetInfo
    _G.BNGetNumConversationMembers = savedGetNumMembers
    _G.BNGetConversationMemberInfo = savedGetMemberInfo
  end

  -- ----------------------------------------------------------------
  -- 4. RegisterGroupEvents calls frame:RegisterEvent for each of the
  --    5 group event names
  -- ----------------------------------------------------------------
  do
    local registeredEvents = {}
    local fakeFrame = {
      RegisterEvent = function(_, eventName)
        registeredEvents[eventName] = true
      end,
      UnregisterEvent = function(_, eventName)
        registeredEvents[eventName] = nil
      end,
    }

    EventBridge.RegisterGroupEvents(fakeFrame)

    local expectedEvents = {
      "CHAT_MSG_PARTY",
      "CHAT_MSG_PARTY_LEADER",
      "CHAT_MSG_INSTANCE_CHAT",
      "CHAT_MSG_INSTANCE_CHAT_LEADER",
      "CHAT_MSG_BN_CONVERSATION",
    }
    for _, name in ipairs(expectedEvents) do
      assert(registeredEvents[name] == true, "RegisterGroupEvents should register " .. name)
    end
  end
end
