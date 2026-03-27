local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Availability = require("WhisperMessenger.Transport.Availability")

return function()
  local sentMessages = {}
  local refreshCalls = 0

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
    store = { conversations = {} },
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
end
