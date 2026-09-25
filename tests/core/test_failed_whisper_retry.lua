local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local QueuedSends = require("WhisperMessenger.Core.Bootstrap.QueuedSends")
local Router = require("WhisperMessenger.Core.EventRouter")
local Store = require("WhisperMessenger.Model.ConversationStore")

-- Whisper an offline player, get "(Not sent)", click Retry while they are
-- still offline: the message goes out again and comes back as "(Not sent)"
-- instead of vanishing.

local TEMPLATE = "No player named '%s' is currently playing."

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

local function failedMessages(runtime)
  local found = {}
  for key, conversation in pairs(runtime.store.conversations) do
    for _, message in ipairs(conversation.messages or {}) do
      if message.delivery == "failed" then
        found[#found + 1] = { key = key, message = message }
      end
    end
  end
  return found
end

local function noop() end

return function()
  rawset(_G, "ERR_CHAT_PLAYER_NOT_FOUND_S", TEMPLATE)
  local offlineLine = { text = string.format(TEMPLATE, "Thrall-Nagrand") }

  -- test_retry_to_a_still_offline_player_shows_not_sent_again
  do
    local sent = {}
    local runtime = newRuntime(sent)
    SendHandler.HandleSend(runtime, {
      conversationKey = "me::WOW::thrall-nagrand",
      target = "Thrall-Nagrand",
      displayName = "Thrall",
      channel = "WOW",
      text = "hello",
    }, noop)
    Router.HandleEvent(runtime, "CHAT_MSG_SYSTEM", offlineLine)
    local first = failedMessages(runtime)
    assert(#first == 1, "first send marked Not sent")

    assert(QueuedSends.HandleAction(runtime, first[1].key, first[1].message, "retry", SendHandler, noop) == true, "Retry sends")
    assert(#sent == 2 and sent[2].text == "hello" and sent[2].target == "Thrall-Nagrand", "same whisper went out again")

    Router.HandleEvent(runtime, "CHAT_MSG_SYSTEM", offlineLine)
    local second = failedMessages(runtime)
    assert(#second == 1 and second[1].message ~= first[1].message, "one fresh Not sent, not zero and not two")
    assert(second[1].message.text == "hello" and second[1].key == first[1].key, "same text in the same chat")
  end
end
