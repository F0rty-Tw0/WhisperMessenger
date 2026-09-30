-- Flipping the BattleTag option must repaint the sender names on the open
-- conversation's bubbles, even though no message changed.

local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local DisplayName = require("WhisperMessenger.Util.DisplayName")

return function()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 300)
  local transcript = ScrollView.Create(factory, parent, {
    width = 400,
    height = 300,
    step = TranscriptView.TRANSCRIPT_SCROLL_STEP,
  })
  transcript.factory = factory
  TranscriptSetup.ConfigureTranscript(factory, transcript, 400)

  local messages = {
    { direction = "in", kind = "user", playerName = "Arthas#1234", sentAt = 1, text = "hello" },
  }

  -- test_bubble_sender_label_follows_the_battletag_option
  DisplayName.Configure({ hideBattleTagNumbers = true })
  TranscriptView.RenderTranscript(transcript, messages)
  assert(FindUI.text(transcript.content, "Arthas") ~= nil, "sender starts without the number")

  DisplayName.Configure({ hideBattleTagNumbers = false })
  TranscriptView.RenderTranscript(transcript, messages)
  assert(FindUI.text(transcript.content, "Arthas#1234") ~= nil, "sender shows the full BattleTag after the toggle")
  assert(FindUI.text(transcript.content, "Arthas") == nil, "the stale short name is gone")
  DisplayName.Configure({ hideBattleTagNumbers = true })
end
