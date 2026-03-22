local Store = require("WhisperMessenger.Model.ConversationStore")
local Availability = require("WhisperMessenger.Transport.Availability")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local state = Store.New({ maxMessagesPerConversation = 20 })
  local key = "me::WOW::arthas-area52"

  Store.AppendIncoming(state, key, {
    id = "msg-1",
    direction = "in",
    kind = "user",
    text = "hi there",
    sentAt = 1,
    playerName = "Arthas-Area52",
  }, false)

  -- Set active status (simulates AFK event)
  Store.SetActiveStatus(state, key, {
    eventName = "CHAT_MSG_AFK",
    text = "I am away from keyboard.",
  })

  assert(state.conversations[key].unreadCount == 1)

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  local conv = state.conversations[key]
  local pane = ConversationPane.Create(factory, parent, {
    displayName = "Arthas-Area52",
  }, conv)

  ConversationPane.SetStatus(pane, Availability.FromStatus("Offline"))
  assert(pane.statusBanner.text == "Offline")

  -- Active status banner shows AFK text
  assert(pane.activeStatusBanner.shown == true, "expected active status banner visible")
  assert(pane.activeStatusBanner.text == "I am away from keyboard.")

  -- Only the user message in transcript, no system message
  assert(#pane.transcript.lines == 1, "expected 1 transcript line, got " .. #pane.transcript.lines)
end
