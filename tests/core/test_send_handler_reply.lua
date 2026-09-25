local SendHandler = require("WhisperMessenger.Core.Bootstrap.SendHandler")
local Router = require("WhisperMessenger.Core.EventRouter")
local Store = require("WhisperMessenger.Model.ConversationStore")

-- Sending a reply: the whisper is the plain typed text; an addon peer also
-- gets the reply link after the identity payload; the stored outgoing
-- message carries replyTo once the game echoes it.
local KEY = "wow::WOW::thrall-nagrand"

local function newRuntime(whispers, addonMessages)
  return {
    sendStatusByConversation = {},
    pendingOutgoing = {},
    availabilityByGUID = {},
    now = function()
      return 100
    end,
    localProfileId = "wow",
    chatApi = {
      SendChatMessage = function(text, _chatType, _languageID, target)
        whispers[#whispers + 1] = { text = text, target = target }
      end,
      RegisterAddonMessagePrefix = function()
        return true
      end,
      SendAddonMessage = function(prefix, payload, _channel, target)
        addonMessages[#addonMessages + 1] = { prefix = prefix, payload = payload, target = target }
      end,
    },
    bnetApi = {},
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
  }
end

local function replyPayload()
  return {
    conversationKey = KEY,
    target = "Thrall-Nagrand",
    displayName = "Thrall-Nagrand",
    channel = "WOW",
    text = "on my way",
    replyTo = { id = "9", wireId = "their1", direction = "in", author = "Thrall", snippet = "you coming?" },
  }
end

return function()
  -- test_reply_whisper_is_plain_text_and_link_follows_identity
  do
    local whispers, addonMessages = {}, {}
    local runtime = newRuntime(whispers, addonMessages)
    runtime.livePresencePeers = { [KEY] = true }
    local payload = replyPayload()
    assert(SendHandler.HandleSend(runtime, payload, function() end) == true, "sent")
    assert(#whispers == 1 and whispers[1].text == "on my way", "recipient without the addon sees exactly the typed text")
    assert(#addonMessages == 2, "identity + reply link, got " .. #addonMessages)
    assert(string.sub(addonMessages[1].payload, 1, 4) == "1|I|", "identity first")
    assert(addonMessages[2].payload == "1|Q|" .. payload.wireId .. "|their1|Y", "reply link: " .. addonMessages[2].payload)
    assert(addonMessages[2].prefix == "WMRX", "same WMRX prefix")

    Router.HandleEvent(runtime, "CHAT_MSG_WHISPER_INFORM", { text = "on my way", playerName = "Thrall-Nagrand" })
    local messages = runtime.store.conversations[KEY].messages
    local stored = messages[#messages]
    assert(stored.text == "on my way" and stored.replyTo and stored.replyTo.snippet == "you coming?", "echo stores the quote")
  end

  -- test_no_link_for_contacts_without_the_addon
  do
    local whispers, addonMessages = {}, {}
    local runtime = newRuntime(whispers, addonMessages)
    SendHandler.HandleSend(runtime, replyPayload(), function() end)
    assert(#addonMessages == 1, "only the usual identity payload")
  end
end
