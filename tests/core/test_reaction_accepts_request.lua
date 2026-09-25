local Store = require("WhisperMessenger.Model.ConversationStore")
local ReactionHandler = require("WhisperMessenger.Core.Bootstrap.ReactionHandler")

-- Reacting to a message request is answering it, the same as replying: the
-- conversation leaves the Requests inbox.

local KEY = "me::WOW::stranger-area52"

return function()
  -- test_sent_reaction_accepts_the_request
  do
    local runtime = {
      localProfileId = "me",
      localPlayerName = "Artio",
      store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
      pendingOutgoing = {},
      sendStatusByConversation = {},
      availabilityByGUID = {},
      now = function()
        return 200
      end,
      chatApi = {
        SendChatMessage = function() end,
        RegisterAddonMessagePrefix = function() end,
        SendAddonMessage = function() end,
      },
      bnetApi = {},
    }
    local target = { kind = "user", direction = "in", text = "hi", wireId = "t1", sentAt = 190, playerName = "Stranger-Area52" }
    local conversation = Store.EnsureConversation(runtime.store, KEY)
    conversation.messages = { target }
    conversation.request = true
    local contact = { conversationKey = KEY, displayName = "Stranger-Area52", guid = "Player-9", channel = "WOW" }

    assert(ReactionHandler.HandleReact(runtime, contact, target, "heart", function() end) == true, "reaction sent")
    assert(conversation.request == nil, "request accepted by the reaction")
  end
end
