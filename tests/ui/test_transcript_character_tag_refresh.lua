-- A Battle.net chat's transcript tags the lines the friend sent from a
-- character, and the tag follows the open chat even when the lines stay the same.

local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")

-- Shown FontString with this text; pooled leftovers stay hidden and are skipped.
local function shown(root, text)
  return FindUI.find(root, function(node)
    return node.frameType == "FontString" and node.text == text and node:IsShown()
  end)
end

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

  local lines = { { direction = "in", kind = "user", channel = "WOW", playerName = "Arthas", sentAt = 1, text = "hi" } }

  -- test_bn_chat_transcript_tags_the_character_line
  transcript.conversationContact = { channel = "BN", displayName = "Friend#1234" }
  TranscriptView.RenderTranscript(transcript, lines)
  assert(shown(transcript.content, "Friend"), "the friend's name reaches the bubble label")
  assert(shown(transcript.content, "- via Arthas"), "the character tag reaches the bubble label")

  -- test_same_lines_relabel_when_the_open_chat_changes
  -- The merge swaps the open chat from the character to the friend; the lines can be the same tables.
  transcript.conversationContact = { channel = "WOW", displayName = "Arthas" }
  TranscriptView.RenderTranscript(transcript, lines)
  assert(not shown(transcript.content, "- via Arthas"), "a character chat drops the tag")
  transcript.conversationContact = { channel = "BN", displayName = "Friend#1234" }
  TranscriptView.RenderTranscript(transcript, lines)
  assert(shown(transcript.content, "- via Arthas"), "the tag comes back once the friend's chat is open")

  -- test_same_lines_relabel_when_only_the_chat_name_changes
  transcript.conversationContact = { channel = "BN", displayName = "Sylvanas#5678" }
  TranscriptView.RenderTranscript(transcript, lines)
  assert(shown(transcript.content, "Sylvanas"), "a new chat name alone relabels the line")

  -- test_same_lines_relabel_when_only_the_chat_channel_changes
  transcript.conversationContact = { channel = "WOW", displayName = "Sylvanas#5678" }
  TranscriptView.RenderTranscript(transcript, lines)
  assert(not shown(transcript.content, "- via Arthas"), "a new chat channel alone drops the tag")
end
