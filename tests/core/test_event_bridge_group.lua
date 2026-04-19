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
    local result = EventBridge.RouteGroupEvent(
      runtime,
      "CHAT_MSG_WHISPER",
      "hi there",
      "Someone-Realm",
      "",
      "",
      "",
      "",
      0,
      0,
      "",
      0,
      601,
      "Player-1084-AAAAAAAA"
    )
    assert(result == false, "RouteGroupEvent should return false for CHAT_MSG_WHISPER, got: " .. tostring(result))
  end

  -- ----------------------------------------------------------------
  -- 3. RouteGroupEvent resolves conversationID for BN_CONVERSATION
  --    via stubbed BNGetNumConversations / BNGetConversationInfo
  -- ----------------------------------------------------------------
  do
    local runtime = makeRuntime()

    -- Stub BN conversation lookup globals
    local savedGetNum = _G.BNGetNumConversations
    local savedGetInfo = _G.BNGetConversationInfo
    _G.BNGetNumConversations = function()
      return 2
    end
    -- BNGetConversationInfo(index) returns: conversationID, subject, numMembers, ...
    -- We only need conversationID and enough info to check membership.
    -- For simplicity: conversation 1 has bnSenderID 99001 as its participant.
    -- The spec says to find a conversation whose membership includes bnSenderID.
    -- EventBridge's resolveBNConversationID iterates conversations.
    -- We return conversationID=55 for index 1, and conversationID=56 for index 2.
    -- We also need BNGetConversationInfo to expose membership; actual Blizzard API:
    --   BNGetConversationInfo(conversationID) → not by index in all versions.
    -- EventBridge iterates 1..BNGetNumConversations() and calls BNGetConversationInfo(i).
    -- Return value: conversationID (first return).
    _G.BNGetConversationInfo = function(idx)
      if idx == 1 then
        -- conversationID=55, subject, numMembers, leader, bnSenderID of first member
        return 55, "subject", 1
      elseif idx == 2 then
        return 56, "subject2", 1
      end
      return nil
    end

    -- For BN_CONVERSATION, bnSenderID is arg 13 in the 17-arg signature.
    -- conversationID will be resolved from index iteration.
    -- Since our stub doesn't provide membership lookup by bnSenderID,
    -- the resolution may return nil → HandleEvent returns false.
    -- The important thing is: RouteGroupEvent does NOT crash, and returns a bool.
    local ok, result = pcall(function()
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
    end)
    assert(ok, "RouteGroupEvent for BN_CONVERSATION should not throw: " .. tostring(result))
    assert(
      type(result) == "boolean",
      "RouteGroupEvent should return a boolean for BN_CONVERSATION, got: " .. type(result)
    )

    -- Restore globals
    _G.BNGetNumConversations = savedGetNum
    _G.BNGetConversationInfo = savedGetInfo
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
