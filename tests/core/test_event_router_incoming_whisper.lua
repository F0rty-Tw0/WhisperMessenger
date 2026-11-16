local Store = require("WhisperMessenger.Model.ConversationStore")
local Protocol = require("WhisperMessenger.Model.MessageReactionProtocol")
local WhisperMessage = require("WhisperMessenger.Core.EventRouter.WhisperMessage")
local IncomingWhisper = require("WhisperMessenger.Core.EventRouter.IncomingWhisper")

-- The incoming-whisper branch, called the way the router calls it: contact,
-- key, on-screen flag and time are already resolved.
local KEY = "wow::WOW::arthas-area52"

local function newState()
  return {
    localProfileId = "me",
    store = Store.New({ maxMessagesPerConversation = 10 }),
    availabilityByGUID = {},
    pendingOutgoing = {},
    now = function()
      return 1000
    end,
  }
end

local function handle(state, text, isActive)
  local payload = { text = text, playerName = "Arthas-Area52", guid = "Player-1", lineID = 1 }
  local contact, key = WhisperMessage.BuildConversationContact(state, payload)
  return IncomingWhisper.Handle(state, "CHAT_MSG_WHISPER", payload, contact, key, isActive, 1000)
end

local function test_plain_whisper_is_stored_unread()
  local state = newState()
  local conversation, meta = handle(state, "hello", false)
  assert(conversation == state.store.conversations[KEY] and conversation.conversationKey == KEY, "whisper should return its stored conversation")
  assert(#conversation.messages == 1 and conversation.messages[1].text == "hello", "whisper should be stored")
  assert(conversation.unreadCount == 1, "a background whisper should count as unread")
  assert(meta and meta.outgoingFromPendingSend == false, "an incoming whisper never comes from a pending send")
end

local function test_whisper_on_screen_is_not_unread()
  local state = newState()
  local conversation = handle(state, "hello", true)
  assert(conversation.unreadCount == 0, "an on-screen whisper should not count as unread")
end

local function test_reaction_fallback_without_metadata_is_staged()
  local state = newState()
  local target = { kind = "user", direction = "out", text = "Ready?", wireId = "target1", sentAt = 990 }
  state.store.conversations[KEY] = { conversationKey = KEY, messages = { target }, unreadCount = 0 }
  local conversation, meta = handle(state, Protocol.BuildFallback("heart", "set", target.text), false)
  assert(conversation == nil and meta and meta.reactionStaged == true, "a reaction fallback should wait for its metadata")
  assert(#state.store.conversations[KEY].messages == 1, "a staged fallback must not be stored as a message")
end

return function()
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil
  test_plain_whisper_is_stored_unread()
  test_whisper_on_screen_is_not_unread()
  test_reaction_fallback_without_metadata_is_staged()
  _G.C_Timer = savedTimer
end
