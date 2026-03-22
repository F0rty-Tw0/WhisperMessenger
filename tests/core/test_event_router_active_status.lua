local Store = require("WhisperMessenger.Model.ConversationStore")
local Queue = require("WhisperMessenger.Model.LockdownQueue")
local Router = require("WhisperMessenger.Core.EventRouter")

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

  -- Send a normal whisper first to create the conversation
  Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
    text = "hi there",
    playerName = "Arthas-Area52",
    lineID = 101,
    guid = "Player-3676-0ABCDEF0",
  })

  local key = "wow::WOW::arthas-area52"
  local conv = state.store.conversations[key]
  assert(conv ~= nil, "conversation should exist")
  assert(#conv.messages == 1, "expected 1 message")

  -- AFK event should set activeStatus, NOT append a system message
  Router.HandleEvent(state, "CHAT_MSG_AFK", {
    text = "Away from keyboard",
    playerName = "Arthas-Area52",
    lineID = 103,
    guid = "Player-3676-0ABCDEF0",
  })
  assert(#conv.messages == 1, "expected still 1 message (AFK should not add system message), got " .. #conv.messages)
  assert(conv.activeStatus ~= nil, "expected activeStatus to be set")
  assert(conv.activeStatus.text == "Away from keyboard")
  assert(conv.activeStatus.eventName == "CHAT_MSG_AFK")

  -- DND event should also set activeStatus
  Router.HandleEvent(state, "CHAT_MSG_DND", {
    text = "Do not disturb",
    playerName = "Arthas-Area52",
    lineID = 104,
    guid = "Player-3676-0ABCDEF0",
  })
  assert(#conv.messages == 1, "expected still 1 message after DND")
  assert(conv.activeStatus.text == "Do not disturb")
  assert(conv.activeStatus.eventName == "CHAT_MSG_DND")

  -- Normal incoming whisper clears activeStatus
  Router.HandleEvent(state, "CHAT_MSG_WHISPER", {
    text = "I'm back!",
    playerName = "Arthas-Area52",
    lineID = 105,
    guid = "Player-3676-0ABCDEF0",
  })
  assert(#conv.messages == 2, "expected 2 messages after normal whisper")
  assert(conv.activeStatus == nil, "expected activeStatus cleared by normal whisper")

  -- Offline system message should still be appended normally
  Router.HandleEvent(state, "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE", {
    text = "Player is offline",
    playerName = "Arthas-Area52",
    lineID = 106,
    guid = "Player-3676-0ABCDEF0",
    channel = "BN",
    bnetAccountID = 42,
    accountInfo = { battleTag = "Arthas#1234" },
  })
  local bnKey = "bnet::BN::42"
  local bnConv = state.store.conversations[bnKey]
  assert(bnConv ~= nil, "expected BNet conversation for offline event")
  assert(bnConv.messages[1].kind == "system", "offline event should still be system message")
end
