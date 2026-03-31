local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Availability = require("WhisperMessenger.Transport.Availability")
local Store = require("WhisperMessenger.Model.ConversationStore")

return function()
  local sentMessages = {}
  local refreshCalls = 0
  local savedInCombatLockdown = _G.InCombatLockdown
  _G.InCombatLockdown = function()
    return false
  end

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
  runtime.isChatMessagingLocked = function()
    return true
  end
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
  runtime.isChatMessagingLocked = function()
    return false
  end
  _G.InCombatLockdown = function()
    return true
  end
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

  _G.InCombatLockdown = savedInCombatLockdown
end
