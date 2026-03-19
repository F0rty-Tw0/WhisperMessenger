local Store = require("WhisperMessenger.Model.ConversationStore")
local Queue = require("WhisperMessenger.Model.LockdownQueue")
local Router = require("WhisperMessenger.Core.EventRouter")
local fixture = dofile("tests/fixtures/whispers.lua")

return function()
  local state = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    queue = Queue.New(),
    activeConversationKey = nil,
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 500
    end,
    isChatMessagingLocked = function()
      return false
    end,
  }

  Router.HandleEvent(state, fixture.incoming.eventName, fixture.incoming.payload)

  local key = "me::WOW::arthas-area52"
  local conversation = state.store.conversations[key]
  assert(conversation.unreadCount == 1)
  assert(#conversation.messages == 1)
  assert(conversation.messages[1].direction == "in")

  Router.RecordPendingSend(state, { channel = "WOW", displayName = "Arthas-Area52" }, "hello back")
  assert(#conversation.messages == 1)

  Router.HandleEvent(state, fixture.inform.eventName, fixture.inform.payload)
  assert(#conversation.messages == 2)
  assert(conversation.messages[2].direction == "out")

  Router.HandleEvent(state, fixture.afk.eventName, fixture.afk.payload)
  assert(#conversation.messages == 3)
  assert(conversation.messages[3].kind == "system")
  assert(conversation.unreadCount == 1)

  Router.HandleEvent(state, fixture.availability.eventName, fixture.availability.payload)
  assert(state.availabilityByGUID["Player-3676-0ABCDEF0"].status == "Offline")

  local missingGuidResult = Router.HandleEvent(state, fixture.availability.eventName, { status = "Offline" })
  assert(missingGuidResult == nil)

  Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
    text = "guidless ping",
    playerName = "Jaina-Proudmoore",
  })

  local fallbackConversation = state.store.conversations["me::WOW::jaina-proudmoore"]
  assert(fallbackConversation ~= nil)
  assert(fallbackConversation.messages[1].id == "500")
  assert(fallbackConversation.messages[1].guid == nil)
end