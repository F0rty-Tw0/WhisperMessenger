local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local QueuedSends = require("WhisperMessenger.Core.Bootstrap.QueuedSends")
local Router = require("WhisperMessenger.Core.EventRouter")
local Store = require("WhisperMessenger.Model.ConversationStore")

-- A long whisper to an offline player: the game rejects every part with
-- its own "No player named" line, but the player sees one failed bubble
-- with the whole message, and Retry sends the whole message again.

local TEMPLATE = "No player named '%s' is currently playing."
local KEY = "wow::WOW::thrall-nagrand"

-- 100 words of 9 letters: four 255-byte parts.
local function longText()
  local list = {}
  for index = 1, 100 do
    list[index] = "abcdefghi"
  end
  return table.concat(list, " ")
end

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

local function sendLong(runtime)
  SendHandler.HandleSend(runtime, {
    conversationKey = KEY,
    target = "Thrall-Nagrand",
    displayName = "Thrall-Nagrand",
    channel = "WOW",
    text = longText(),
  }, function() end)
end

local function rejectEveryPart(runtime, count)
  for _ = 1, count do
    Router.HandleEvent(runtime, "CHAT_MSG_SYSTEM", { text = string.format(TEMPLATE, "Thrall-Nagrand") })
  end
end

return function()
  rawset(_G, "ERR_CHAT_PLAYER_NOT_FOUND_S", TEMPLATE)

  -- test_offline_recipient_of_four_parts_gets_one_failed_record_with_full_text
  do
    local sent = {}
    local runtime = newRuntime(sent)
    sendLong(runtime)
    assert(#sent == 4, "four parts went out")
    rejectEveryPart(runtime, 4)
    local messages = runtime.store.conversations[KEY].messages
    assert(#messages == 1, "one failed bubble, got " .. #messages)
    assert(messages[1].delivery == "failed" and messages[1].text == longText(), "failed record holds the whole message")
    assert(next(runtime.pendingOutgoing) == nil, "sibling parts dropped")
  end

  -- test_retry_resends_the_whole_message
  do
    local sent = {}
    local runtime = newRuntime(sent)
    sendLong(runtime)
    rejectEveryPart(runtime, 4)
    local failed = runtime.store.conversations[KEY].messages[1]
    assert(QueuedSends.HandleAction(runtime, KEY, failed, "retry", SendHandler, function() end) == true, "retried")
    assert(#sent == 8, "all four parts sent again, got " .. #sent)
  end

  rawset(_G, "ERR_CHAT_PLAYER_NOT_FOUND_S", nil)
end
