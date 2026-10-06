-- Flipping the class-colour option must repaint the sender names on the open
-- conversation's bubbles, even though no message changed.

local FakeUI = require("tests.helpers.fake_ui")
local FindUI = require("tests.helpers.find_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local DisplayName = require("WhisperMessenger.Util.DisplayName")
local Theme = require("WhisperMessenger.UI.Theme")

local MAGE = { 0.25, 0.78, 0.92 }

-- Shown sender-name FontString; pooled leftovers stay hidden and are skipped.
local function shownName(root, text)
  return FindUI.find(root, function(node)
    return node.frameType == "FontString" and node.text == text and node:IsShown()
  end)
end

-- Alpha is compared too: text_secondary is white at partial alpha.
local function assertNameColor(root, expected, label)
  local fs = shownName(root, "Jaina")
  assert(fs, label .. ": sender name not found")
  local actual = { fs:GetTextColor() }
  local matches = math.abs(actual[4] - (expected[4] or 1)) < 0.001
  for i = 1, 3 do
    matches = matches and math.abs(actual[i] - expected[i]) < 0.001
  end
  assert(matches, label .. ": got " .. table.concat(actual, ", "))
end

return function()
  local previousClassColors = _G.RAID_CLASS_COLORS
  _G.RAID_CLASS_COLORS = { MAGE = { r = MAGE[1], g = MAGE[2], b = MAGE[3] } }

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
    { direction = "in", kind = "user", playerName = "Jaina", classTag = "MAGE", sentAt = 1, text = "hi" },
  }

  -- test_bubble_sender_colour_follows_the_class_colour_option
  DisplayName.Configure({ classColorSenderNames = true })
  TranscriptView.RenderTranscript(transcript, messages)
  assertNameColor(transcript.content, MAGE, "sender starts mage-coloured")

  DisplayName.Configure({ classColorSenderNames = false })
  TranscriptView.RenderTranscript(transcript, messages)
  assertNameColor(transcript.content, Theme.COLORS.text_secondary, "sender drops the class colour after the toggle")

  DisplayName.Configure({ classColorSenderNames = true })
  TranscriptView.RenderTranscript(transcript, messages)
  assertNameColor(transcript.content, MAGE, "sender is mage-coloured again after toggling back")

  -- test_whisper_fallback_colours_sender_without_class
  -- Only the fallback changes between renders, so the relayout must be forced by it.
  local classless = {
    { direction = "in", kind = "user", playerName = "Jaina", sentAt = 1, text = "hi" },
  }
  TranscriptView.RenderTranscript(transcript, classless)
  assertNameColor(transcript.content, Theme.COLORS.text_secondary, "classless sender starts text_secondary")
  transcript.senderFallbackClassTag = "MAGE"
  TranscriptView.RenderTranscript(transcript, classless)
  assertNameColor(transcript.content, MAGE, "classless sender takes the whisper fallback class")
  transcript.senderFallbackClassTag = nil
  TranscriptView.RenderTranscript(transcript, classless)
  assertNameColor(transcript.content, Theme.COLORS.text_secondary, "sender drops the fallback colour once it is cleared")

  DisplayName.Configure({ classColorSenderNames = false })
  _G.RAID_CLASS_COLORS = previousClassColors
end
