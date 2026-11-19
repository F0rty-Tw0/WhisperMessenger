local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")

-- The pane hands the open chat to the transcript, so a Battle.net chat can
-- tag the lines the friend sent from a character.
return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(600, 420)
  local pane = ConversationPane.Create(factory, parent, nil, nil)

  -- test_pane_hands_the_open_chat_to_the_transcript
  local contact = { conversationKey = "bnet::BN::friend#1234", channel = "BN", displayName = "Friend#1234" }
  ConversationPane.Refresh(pane, contact, { messages = {} })
  assert(pane.transcript.conversationContact == contact, "the transcript knows the open chat")
  ConversationPane.Refresh(pane, nil, nil)
  assert(pane.transcript.conversationContact == nil, "no open chat: nothing left over")
end
