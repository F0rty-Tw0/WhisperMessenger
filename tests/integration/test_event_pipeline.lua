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

  local key = "wow::WOW::arthas-area52"
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
  assert(#conversation.messages == 2, "AFK should not add a message, got " .. #conversation.messages)
  assert(conversation.activeStatus ~= nil, "AFK should set activeStatus")
  assert(conversation.activeStatus.text == "Away from keyboard")
  assert(conversation.unreadCount == 1)

  Router.HandleEvent(state, fixture.availability.eventName, fixture.availability.payload)
  assert(state.availabilityByGUID["Player-3676-0ABCDEF0"].status == "Offline")

  local missingGuidResult = Router.HandleEvent(state, fixture.availability.eventName, { status = "Offline" })
  assert(missingGuidResult == nil)

  Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
    text = "guidless ping",
    playerName = "Jaina-Proudmoore",
  })

  local fallbackConversation = state.store.conversations["wow::WOW::jaina-proudmoore"]
  assert(fallbackConversation ~= nil)
  assert(fallbackConversation.messages[1].id == "500")
  assert(fallbackConversation.messages[1].guid == nil)

  -- BNet whisper with playerInfo carries classTag into stored message
  Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER", {
    text = "hello from bn",
    playerName = "Jaina",
    lineID = 501,
    guid = nil,
    channel = "BN",
    bnetAccountID = 42,
    accountInfo = {
      battleTag = "Jaina#1234",
      gameAccountInfo = {
        characterName = "Jaina",
        realmName = "Proudmoore",
        playerGuid = "Player-60-0ABCDE123",
        className = "Mage",
        raceName = "Human",
        factionName = "Alliance",
      },
    },
    playerInfo = {
      className = "Mage",
      classTag = "MAGE",
      raceName = "Human",
      raceTag = "Human",
    },
  })

  local bnConv = state.store.conversations["bnet::BN::jaina#1234"]
  assert(bnConv ~= nil, "expected BNet conversation to be created")
  assert(bnConv.className == "Mage", "expected BNet conversation className")
  assert(bnConv.classTag == "MAGE", "expected BNet conversation classTag from playerInfo")
  assert(bnConv.messages[1].classTag == "MAGE", "expected BNet message classTag for chat bubble icons")
end
