local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local MessageReplies = require("WhisperMessenger.Model.MessageReplies")
local Router = require("WhisperMessenger.Core.EventRouter")

-- A reply from another WhisperMessenger user shows the same quote here,
-- whether the reply link arrives after or before the whisper itself.
local KEY = "wow::WOW::arthas-area52"

local function newState()
  local state = {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 20, maxConversations = 10 }),
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 100
    end,
  }
  return state
end

local function addonEvent(text)
  return { prefix = "WMRX", text = text, channel = "WHISPER", playerName = "Arthas-Area52" }
end

local function whisperEvent(text, lineID)
  return { text = text, playerName = "Arthas-Area52", guid = "Player-1", lineID = lineID }
end

local function seedMyMessage(state)
  Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent("hi", 1))
  Store.AppendOutgoing(state.store, KEY, { id = "o1", direction = "out", kind = "user", wireId = "old1", text = "are you coming?", sentAt = 90 })
end

local function lastMessage(state)
  local messages = state.store.conversations[KEY].messages
  return messages[#messages]
end

return function()
  -- test_link_after_whisper_and_identity_attaches_the_quote
  do
    local state = newState()
    seedMyMessage(state)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent("yes", 2))
    Router.HandleEvent(state, "CHAT_MSG_ADDON", addonEvent(Protocol.EncodeIdentity("new1", "yes")))
    local result = Router.HandleEvent(state, "CHAT_MSG_ADDON", addonEvent("1|Q|new1|old1|Y"))
    assert(result and result.conversationKey == KEY, "returns the conversation so the window refreshes")
    local reply = lastMessage(state).replyTo
    assert(reply and reply.wireId == "old1" and reply.snippet == "are you coming?", "quote attached")
  end

  -- test_link_before_whisper_is_claimed_when_the_whisper_lands
  do
    local state = newState()
    seedMyMessage(state)
    Router.HandleEvent(state, "CHAT_MSG_ADDON", addonEvent(Protocol.EncodeIdentity("new2", "on my way")))
    Router.HandleEvent(state, "CHAT_MSG_ADDON", addonEvent("1|Q|new2|old1|Y"))
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent("on my way", 3))
    local message = lastMessage(state)
    assert(message.text == "on my way" and message.wireId == "new2", "whisper paired with its identity")
    assert(message.replyTo and message.replyTo.snippet == "are you coming?", "staged quote claimed")
  end

  -- test_link_between_whisper_and_identity_is_claimed_on_identity
  do
    local state = newState()
    seedMyMessage(state)
    Router.HandleEvent(state, "CHAT_MSG_WHISPER", whisperEvent("sure", 4))
    Router.HandleEvent(state, "CHAT_MSG_ADDON", addonEvent("1|Q|new3|old1|Y"))
    Router.HandleEvent(state, "CHAT_MSG_ADDON", addonEvent(Protocol.EncodeIdentity("new3", "sure")))
    assert(lastMessage(state).replyTo ~= nil, "claimed when the identity pairs")
  end

  -- test_unknown_future_kind_is_ignored_like_old_clients_ignore_Q
  do
    local state = newState()
    seedMyMessage(state)
    local before = #state.store.conversations[KEY].messages
    assert(Router.HandleEvent(state, "CHAT_MSG_ADDON", addonEvent("1|Z|abc|def|M")) == nil, "unknown kind dropped")
    assert(#state.store.conversations[KEY].messages == before, "no messages added")
    assert(MessageReplies.DecodeLink("1|Z|abc|def|M") == nil, "not a reply link")
  end
end
