local Store = require("WhisperMessenger.Model.ConversationStore")
local PendingOutgoing = require("WhisperMessenger.Core.EventRouter.PendingOutgoing")
local WhisperMessage = require("WhisperMessenger.Core.EventRouter.WhisperMessage")
local OutgoingWhisper = require("WhisperMessenger.Core.EventRouter.OutgoingWhisper")

-- The outgoing-echo branch, called the way the router calls it: contact, key
-- and time are already resolved.
local KEY = "wow::WOW::arthas-area52"
local TARGET = { channel = "WOW", target = "Arthas-Area52", displayName = "Arthas-Area52", guid = "Player-1" }

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

local function handle(state, text)
  local payload = { text = text, playerName = "Arthas-Area52", guid = "Player-1", lineID = 1 }
  local contact, key = WhisperMessage.BuildConversationContact(state, payload)
  return OutgoingWhisper.Handle(state, payload, contact, key, 1000)
end

local function test_echo_without_a_pending_send_is_stored()
  local state = newState()
  local conversation, meta = handle(state, "typed in chat")
  assert(conversation == state.store.conversations[KEY] and conversation.conversationKey == KEY, "echo should return its stored conversation")
  assert(conversation.messages[1].direction == "out" and conversation.messages[1].text == "typed in chat", "echo should be stored as outgoing")
  assert(meta and meta.outgoingFromPendingSend == false, "an echo typed in the default chat is not from a pending send")
end

local function test_echo_of_a_pending_send_carries_its_wire_id()
  local state = newState()
  PendingOutgoing.Record(state, TARGET, "sent here", { wireId = "out1" })
  local conversation, meta = handle(state, "sent here")
  assert(meta and meta.outgoingFromPendingSend == true, "echo of a pending send should say so")
  assert(conversation.messages[1].wireId == "out1", "echo should carry the pending send's wire id")
end

local function test_echo_marks_unread_whispers_read()
  local state = newState()
  Store.AppendIncoming(
    state.store,
    KEY,
    { id = "in1", direction = "in", kind = "user", text = "hi", sentAt = 990, playerName = "Arthas-Area52" },
    false
  )
  local conversation = handle(state, "reply")
  assert(conversation.unreadCount == 0, "replying should mark the conversation read")
end

return function()
  local savedTimer = _G.C_Timer
  _G.C_Timer = nil
  test_echo_without_a_pending_send_is_stored()
  test_echo_of_a_pending_send_carries_its_wire_id()
  test_echo_marks_unread_whispers_read()
  _G.C_Timer = savedTimer
end
