local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local MessageParts = require("WhisperMessenger.Model.MessageParts")
local Router = require("WhisperMessenger.Core.EventRouter")

-- The router folds the parts of a long whisper into one bubble: after an
-- incoming part is stored, after its identity or manifest pairs with a
-- stored part, and after the sender's echo resolves a pending part.
local KEY = "wow::WOW::arthas-area52"
local PARTS = {
  { text = "one" },
  { text = "two", join = " " },
  { text = "three", join = " " },
}

local function newState()
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
  }
end

local function addon(state, text)
  return Router.HandleEvent(state, "CHAT_MSG_ADDON", { prefix = "WMRX", text = text, channel = "WHISPER", playerName = "Arthas-Area52" })
end

local function whisper(state, text, lineID)
  return Router.HandleEvent(state, "CHAT_MSG_WHISPER", { text = text, playerName = "Arthas-Area52", guid = "Player-1", lineID = lineID })
end

local function messages(state)
  return state.store.conversations[KEY].messages
end

return function()
  -- test_parts_stored_after_their_metadata_merge_on_arrival
  do
    local state = newState()
    addon(state, Protocol.EncodeIdentity("abc1", "one"))
    addon(state, MessageParts.EncodeManifest("abc1", PARTS))
    whisper(state, "one", 1)
    whisper(state, "two", 2)
    whisper(state, "three", 3)
    assert(#messages(state) == 1, "one bubble, got " .. #messages(state))
    assert(messages(state)[1].text == "one two three", "full text: " .. messages(state)[1].text)
    assert(state.store.conversations[KEY].unreadCount == 1, "one unread")
  end

  -- test_manifest_after_the_parts_merges_on_pairing
  do
    local state = newState()
    whisper(state, "one", 1)
    whisper(state, "two", 2)
    whisper(state, "three", 3)
    addon(state, Protocol.EncodeIdentity("abc1", "one"))
    local result, meta = addon(state, MessageParts.EncodeManifest("abc1", PARTS))
    assert(result and result.conversationKey == KEY, "returns the conversation")
    assert(meta ~= nil and meta.presence == "identity", "window refreshes")
    assert(#messages(state) == 1 and messages(state)[1].text == "one two three", "merged on pairing")
  end

  -- test_sender_echoes_merge_into_one_bubble
  do
    local state = newState()
    local target = { channel = "WOW", target = "Arthas-Area52", displayName = "Arthas-Area52", guid = "Player-1" }
    for index, part in ipairs(PARTS) do
      Router.RecordPendingSend(state, target, part.text, { wireId = "abc1", partIndex = index, partCount = 3, join = part.join })
    end
    for _, part in ipairs(PARTS) do
      Router.HandleEvent(state, "CHAT_MSG_WHISPER_INFORM", { text = part.text, playerName = "Arthas-Area52", guid = "Player-1" })
    end
    assert(#messages(state) == 1, "one bubble, got " .. #messages(state))
    local message = messages(state)[1]
    assert(message.text == "one two three" and message.direction == "out", "full text: " .. message.text)
    assert(message.partCount == 3 and message.parts == nil, "complete")
  end
end
