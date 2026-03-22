local Store = require("WhisperMessenger.Model.ConversationStore")

return function()
  local state = Store.New({ maxMessagesPerConversation = 20 })
  local key = "me::WOW::arthas-area52"

  -- Initially no activeStatus
  Store.AppendIncoming(state, key, {
    id = "1",
    direction = "in",
    kind = "user",
    text = "hi there",
    sentAt = 1,
    playerName = "Arthas-Area52",
  }, false)
  local conv = state.conversations[key]
  assert(conv.activeStatus == nil, "expected no activeStatus initially")

  -- SetActiveStatus sets the field
  Store.SetActiveStatus(state, key, {
    eventName = "CHAT_MSG_AFK",
    text = "Away from keyboard",
  })
  assert(conv.activeStatus ~= nil, "expected activeStatus to be set")
  assert(conv.activeStatus.text == "Away from keyboard")
  assert(conv.activeStatus.eventName == "CHAT_MSG_AFK")

  -- ClearActiveStatus removes the field
  Store.ClearActiveStatus(state, key)
  assert(conv.activeStatus == nil, "expected activeStatus to be cleared")

  -- SetActiveStatus on non-existent conversation creates it
  local key2 = "me::WOW::jaina-proudmoore"
  Store.SetActiveStatus(state, key2, {
    eventName = "CHAT_MSG_DND",
    text = "Do not disturb",
  })
  assert(state.conversations[key2] ~= nil, "expected conversation to be created")
  assert(state.conversations[key2].activeStatus.text == "Do not disturb")

  -- AppendIncoming with kind "user" clears activeStatus
  Store.SetActiveStatus(state, key, {
    eventName = "CHAT_MSG_AFK",
    text = "Away from keyboard",
  })
  assert(conv.activeStatus ~= nil, "expected activeStatus to be set before incoming")
  Store.AppendIncoming(state, key, {
    id = "2",
    direction = "in",
    kind = "user",
    text = "I'm back!",
    sentAt = 2,
    playerName = "Arthas-Area52",
  }, false)
  assert(conv.activeStatus == nil, "expected activeStatus cleared by incoming user message")

  -- AppendIncoming with kind "system" does NOT clear activeStatus
  Store.SetActiveStatus(state, key, {
    eventName = "CHAT_MSG_AFK",
    text = "Away from keyboard",
  })
  Store.AppendIncoming(state, key, {
    id = "3",
    direction = "in",
    kind = "system",
    text = "Player went offline",
    sentAt = 3,
    playerName = "Arthas-Area52",
    eventName = "CHAT_MSG_BN_WHISPER_PLAYER_OFFLINE",
  }, false)
  assert(conv.activeStatus ~= nil, "expected activeStatus NOT cleared by system message")
end
