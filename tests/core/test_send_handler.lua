local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Availability = require("WhisperMessenger.Transport.Availability")
local Store = require("WhisperMessenger.Model.ConversationStore")

return function()
  local sentMessages = {}
  local refreshCalls = 0
  local savedInCombatLockdown = _G.InCombatLockdown
  local savedBNSendWhisper = _G.BNSendWhisper
  rawset(_G, "InCombatLockdown", function()
    return false
  end)

  local runtime = {
    sendStatusByConversation = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
    localProfileId = "me",
    chatApi = {
      SendChatMessage = function(text, chatType, languageID, target)
        table.insert(sentMessages, { text = text, target = target })
      end,
    },
    bnetApi = {},
    isChatMessagingLocked = function()
      return false
    end,
    -- Stub fields used by EventRouter.RecordPendingSend
    store = Store.New({
      maxMessagesPerConversation = 20,
      maxConversations = 10,
      messageMaxAge = 86400,
      conversationMaxAge = 86400,
    }),
    activeConversationKey = nil,
  }

  local function refreshWindow()
    refreshCalls = refreshCalls + 1
  end

  -- Test 1: Successful character whisper sends directly
  local payload = {
    conversationKey = "me::WOW::thrall-nagrand",
    target = "Thrall-Nagrand",
    displayName = "Thrall-Nagrand",
    channel = "WOW",
    text = "hello",
  }

  local result = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(result == true, "expected send to succeed")
  assert(sentMessages[1].text == "hello")
  assert(sentMessages[1].target == "Thrall-Nagrand")

  -- Test 2: Combat lockdown blocks character whisper sends
  rawset(runtime, "isChatMessagingLocked", function()
    return true
  end)
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}

  local lockedResult = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(lockedResult == false, "expected send to be blocked during lockdown")
  assert(#sentMessages == 0, "should not send during lockdown")
  assert(refreshCalls == 1, "should refresh to show lockdown status")

  local status = runtime.sendStatusByConversation[payload.conversationKey]
  assert(status ~= nil, "expected lockdown status to be set")
  assert(status.status == "Lockdown", "expected Lockdown status, got: " .. tostring(status.status))
  local blockedConversation = runtime.store.conversations[payload.conversationKey]
  assert(blockedConversation ~= nil, "expected blocked send to be recorded in conversation")
  assert(#blockedConversation.messages == 1, "expected one blocked outgoing message")
  assert(blockedConversation.messages[1].delivery == "blocked", "expected blocked outgoing delivery marker")
  assert(blockedConversation.messages[1].text == "hello", "expected blocked outgoing text to be preserved")

  -- Test 3: Global InCombatLockdown blocks character whisper sends
  rawset(runtime, "isChatMessagingLocked", function()
    return false
  end)
  rawset(_G, "InCombatLockdown", function()
    return true
  end)
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}

  local combatResult = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(combatResult == false, "expected send to be blocked when InCombatLockdown is true")
  assert(#sentMessages == 0, "should not send while InCombatLockdown is true")
  assert(refreshCalls == 1, "should refresh to show lockdown status when InCombatLockdown is true")

  local combatStatus = runtime.sendStatusByConversation[payload.conversationKey]
  assert(combatStatus ~= nil, "expected lockdown status while InCombatLockdown is true")
  assert(combatStatus.status == "Lockdown", "expected Lockdown status during InCombatLockdown")
  local combatConversation = runtime.store.conversations[payload.conversationKey]
  assert(combatConversation ~= nil, "expected conversation to exist after InCombatLockdown block")
  assert(#combatConversation.messages == 2, "expected second blocked outgoing message to be recorded")
  assert(
    combatConversation.messages[2].blockedReason == "Lockdown",
    "expected blocked reason Lockdown on InCombatLockdown block"
  )

  -- Test 4: Legacy BNSendWhisper fallback supports Classic/TBC Battle.net sends
  rawset(runtime, "isChatMessagingLocked", function()
    return false
  end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  rawset(_G, "BNSendWhisper", function(bnetAccountID, text)
    table.insert(sentMessages, { bnetAccountID = bnetAccountID, text = text, channel = "BN" })
    return true
  end)
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}

  local bnPayload = {
    conversationKey = "me::BN::jaina#1234",
    displayName = "Jaina#1234",
    channel = "BN",
    bnetAccountID = 77,
    text = "hello bn",
  }

  local bnResult = SendHandler.HandleSend(runtime, bnPayload, refreshWindow)
  assert(bnResult == true, "expected Battle.net send to use legacy BNSendWhisper fallback")
  assert(#sentMessages == 1, "expected one Battle.net message to be sent")
  assert(sentMessages[1].channel == "BN", "expected Battle.net transport marker")
  assert(sentMessages[1].bnetAccountID == 77, "expected bnetAccountID to be forwarded")
  assert(sentMessages[1].text == "hello bn", "expected Battle.net text to be forwarded")

  -- Test 5: Competitive content blocks character whisper sends
  rawset(runtime, "isChatMessagingLocked", function()
    return false
  end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  runtime.isCompetitiveContent = function()
    return true
  end
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}

  local competitiveResult = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(competitiveResult == false, "expected send to be blocked during competitive content")
  assert(#sentMessages == 0, "should not send during competitive content")
  assert(refreshCalls == 1, "should refresh to show competitive status")

  local competitiveStatus = runtime.sendStatusByConversation[payload.conversationKey]
  assert(competitiveStatus ~= nil, "expected competitive status to be set")
  assert(
    competitiveStatus.status == "Competitive Content",
    "expected 'Competitive Content' status, got: " .. tostring(competitiveStatus.status)
  )

  -- Blocked outgoing message should be recorded
  local compConversation = runtime.store.conversations[payload.conversationKey]
  assert(compConversation ~= nil, "expected conversation to exist after competitive block")
  local lastMsg = compConversation.messages[#compConversation.messages]
  assert(lastMsg.delivery == "blocked", "expected blocked delivery marker")
  assert(lastMsg.blockedReason == "Competitive Content", "expected competitive blocked reason")

  -- Test 6: Competitive content does NOT block when isCompetitiveContent returns false
  runtime.isCompetitiveContent = function()
    return false
  end
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}

  local notCompResult = SendHandler.HandleSend(runtime, payload, refreshWindow)
  assert(notCompResult == true, "expected send to succeed when not in competitive content")
  assert(#sentMessages == 1, "should send when not in competitive content")

  runtime.isCompetitiveContent = nil

  -- Test 7: Ignored contact blocks character whisper sends
  rawset(runtime, "isChatMessagingLocked", function()
    return false
  end)
  rawset(_G, "InCombatLockdown", function()
    return false
  end)
  runtime.friendListApi = {
    IsIgnoredByGuid = function(guid)
      return guid == "guid-blocked"
    end,
    IsIgnored = function(name)
      return name == "Thrall-Nagrand"
    end,
  }
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}

  local ignoredPayload = {
    conversationKey = "me::WOW::thrall-nagrand",
    target = "Thrall-Nagrand",
    displayName = "Thrall-Nagrand",
    channel = "WOW",
    text = "you up?",
  }

  local ignoredResult = SendHandler.HandleSend(runtime, ignoredPayload, refreshWindow)
  assert(ignoredResult == false, "expected send to be blocked when contact is ignored")
  assert(#sentMessages == 0, "should not send to ignored contact")
  assert(refreshCalls == 1, "should refresh to surface ignored status")

  local ignoredStatus = runtime.sendStatusByConversation[ignoredPayload.conversationKey]
  assert(
    ignoredStatus ~= nil and ignoredStatus.status == "Ignored",
    "expected Ignored status, got: " .. tostring(ignoredStatus and ignoredStatus.status)
  )
  assert(ignoredStatus.canWhisper ~= true, "Ignored status must not be whisperable")

  local ignoredConv = runtime.store.conversations[ignoredPayload.conversationKey]
  assert(ignoredConv ~= nil, "expected conversation entry for blocked send")
  local ignoredMsg = ignoredConv.messages[#ignoredConv.messages]
  assert(ignoredMsg.delivery == "blocked", "expected blocked delivery marker")
  assert(ignoredMsg.blockedReason == "Ignored", "expected Ignored blocked reason")
  assert(ignoredMsg.text == "you up?", "expected blocked text preserved")

  -- Test 8: Battle.net channel skips the character ignore check
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}
  rawset(_G, "BNSendWhisper", function(bnetAccountID, text)
    table.insert(sentMessages, { bnetAccountID = bnetAccountID, text = text, channel = "BN" })
    return true
  end)

  local bnIgnoredPayload = {
    conversationKey = "me::BN::thrall#1234",
    displayName = "Thrall-Nagrand",
    channel = "BN",
    bnetAccountID = 99,
    text = "bn hello",
  }
  local bnIgnoredResult = SendHandler.HandleSend(runtime, bnIgnoredPayload, refreshWindow)
  assert(bnIgnoredResult == true, "BN sends must bypass character ignore list")
  assert(#sentMessages == 1, "expected BN send to go through")

  -- Test 9: Non-ignored contact passes through normally
  runtime.sendStatusByConversation = {}
  runtime.pendingOutgoing = {}
  refreshCalls = 0
  sentMessages = {}
  local cleanPayload = {
    conversationKey = "me::WOW::jaina-dalaran",
    target = "Jaina-Dalaran",
    displayName = "Jaina-Dalaran",
    channel = "WOW",
    text = "hi",
  }
  local cleanResult = SendHandler.HandleSend(runtime, cleanPayload, refreshWindow)
  assert(cleanResult == true, "non-ignored contact must send normally")
  assert(#sentMessages == 1, "expected message to send")

  runtime.friendListApi = nil

  rawset(_G, "InCombatLockdown", savedInCombatLockdown)
  rawset(_G, "BNSendWhisper", savedBNSendWhisper)
end
