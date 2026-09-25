local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Store = require("WhisperMessenger.Model.ConversationStore")

-- A send during chat lockdown is queued (kept with its target so it can be
-- sent later with a click); a send the game rejects is kept as failed.

local KEY = "me::WOW::thrall-nagrand"

local function newRuntime(sent)
  return {
    sendStatusByConversation = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
    localProfileId = "me",
    chatApi = {
      SendChatMessage = function(text, _chatType, _languageID, target)
        table.insert(sent, { text = text, target = target })
      end,
    },
    bnetApi = {},
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10, messageMaxAge = 86400, conversationMaxAge = 86400 }),
  }
end

local function payload()
  return {
    conversationKey = KEY,
    target = "Thrall-Nagrand",
    displayName = "Thrall",
    channel = "WOW",
    text = "hello",
    replyTo = { wireId = "w1", direction = "in", snippet = "hi" },
  }
end

local function rejectingBNetApi()
  return {
    GetNumFriends = function()
      return 1
    end,
    GetFriendAccountInfo = function()
      return { bnetAccountID = 77, battleTag = "Jaina#1234", isOnline = true, gameAccountInfo = { gameAccountID = 9 } }
    end,
    SendWhisper = function()
      error("rejected")
    end,
  }
end

local function bnetPayload()
  return {
    conversationKey = "me::BN::jaina",
    displayName = "Jaina#1234",
    battleTag = "Jaina#1234",
    bnetAccountID = 77,
    channel = "BN",
    text = "yo",
  }
end

return function()
  -- test_locked_send_is_queued_with_its_target
  do
    local sent = {}
    local runtime = newRuntime(sent)
    runtime.isMythicLockdown = function()
      return true
    end
    local p = payload()
    local result = SendHandler.HandleSend(runtime, p, function() end)
    assert(result == false, "nothing went out")
    assert(#sent == 0, "never sent while locked")
    local message = runtime.store.conversations[KEY].messages[1]
    assert(message.delivery == "queued", "stored as queued, got " .. tostring(message.delivery))
    assert(message.target == "Thrall-Nagrand" and message.text == "hello", "target and text kept for Send now")
    assert(message.replyTo and message.replyTo.wireId == "w1", "reply kept")
    assert(p.deliveryRecorded == true, "caller learns the text is safe in history")
  end

  -- test_competitive_send_is_queued
  do
    local sent = {}
    local runtime = newRuntime(sent)
    runtime.isCompetitiveContent = function()
      return true
    end
    SendHandler.HandleSend(runtime, payload(), function() end)
    assert(runtime.store.conversations[KEY].messages[1].delivery == "queued", "competitive content queues too")
  end

  -- test_locked_reaction_is_not_queued
  do
    local runtime = newRuntime({})
    runtime.isCompetitiveContent = function()
      return true
    end
    local p = payload()
    p.reactionControl = { operation = {} }
    SendHandler.HandleSend(runtime, p, function() end)
    local conversation = runtime.store.conversations[KEY]
    assert(conversation == nil or #conversation.messages == 0, "a reaction adds no unsent message to the chat")
  end

  -- test_rejected_battle_net_reaction_adds_no_failed_message
  do
    local runtime = newRuntime({})
    runtime.bnetApi = rejectingBNetApi()
    rawset(_G, "BNSendWhisper", nil)
    local p = bnetPayload()
    p.reactionControl = { operation = {} }
    assert(SendHandler.HandleSend(runtime, p, function() end) == false, "send failed")
    local conversation = runtime.store.conversations["me::BN::jaina"]
    assert(conversation == nil or #conversation.messages == 0, "a failed reaction adds no Not sent message")
  end

  -- test_rejected_battle_net_send_is_kept_as_failed
  do
    local runtime = newRuntime({})
    runtime.bnetApi = rejectingBNetApi()
    rawset(_G, "BNSendWhisper", nil)
    local p = bnetPayload()
    local result = SendHandler.HandleSend(runtime, p, function() end)
    assert(result == false, "send failed")
    local conversation = runtime.store.conversations["me::BN::jaina"]
    assert(conversation ~= nil, "failed send is kept in history")
    local message = conversation.messages[#conversation.messages]
    assert(message.delivery == "failed" and message.text == "yo", "stored as failed")
    assert(p.deliveryRecorded == true, "caller learns the text is safe in history")
  end
end
