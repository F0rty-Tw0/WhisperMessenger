local Store = require("WhisperMessenger.Model.ConversationStore")
local Availability = require("WhisperMessenger.Transport.Availability")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")

return function()
  local state = Store.New({ maxMessagesPerConversation = 20 })
  Store.AppendIncoming(state, "me::WOW::arthas-area52", {
    id = "afk-1",
    direction = "in",
    kind = "system",
    text = "I am away from keyboard.",
    sentAt = 2,
    playerName = "Arthas-Area52",
  }, false)

  assert(state.conversations["me::WOW::arthas-area52"].unreadCount == 0)

  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  local pane = ConversationPane.Create(factory, parent, {
    displayName = "Arthas-Area52",
  }, {
    messages = state.conversations["me::WOW::arthas-area52"].messages,
  })

  ConversationPane.SetStatus(pane, Availability.FromStatus("Offline"))
  assert(pane.statusBanner.text == "Offline")
  assert(pane.transcript.lines[1] == "[System] I am away from keyboard.")
end
