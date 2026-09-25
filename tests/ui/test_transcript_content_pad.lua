local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local Theme = require("WhisperMessenger.UI.Theme")
local TranscriptRows = require("WhisperMessenger.UI.ConversationPane.TranscriptRows")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")

-- The viewport is flush with the header divider and the composer line; the
-- breathing room lives inside the scroll content instead.
local PAD = 8

local function makeMessages(count)
  local messages = {}
  for index = 1, count do
    messages[index] = {
      id = tostring(index),
      direction = index % 3 == 0 and "out" or "in",
      kind = "user",
      playerName = "Arthas",
      sentAt = index,
      text = "message " .. index,
    }
  end
  return messages
end

local function makeTranscript(width, height)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(width, height)
  local transcript = ScrollView.Create(factory, parent, { width = width, height = height, step = TranscriptView.TRANSCRIPT_SCROLL_STEP })
  transcript.factory = factory
  TranscriptSetup.ConfigureTranscript(factory, transcript, width)
  return transcript
end

local function viewportBottom(transcript)
  return ScrollView.GetOffset(transcript) + transcript.scrollFrame:GetHeight()
end

return function()
  -- test_content_pad_is_eight_pixels
  do
    assert(TranscriptRows.CONTENT_PAD == PAD, "expected content pad " .. PAD .. ", got " .. tostring(TranscriptRows.CONTENT_PAD))
  end

  -- test_viewport_top_is_flush_with_header_divider
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "Parent", nil)
    parent:SetSize(600, 420)
    local view = ConversationPane.Create(factory, parent, { displayName = "Arthas" }, { messages = {} })
    local point = view.transcript.point
    assert(point[1] == "TOPLEFT" and point[2] == view.headerFrame and point[3] == "BOTTOMLEFT", "viewport anchored under the header")
    assert(point[5] == 0, "viewport top flush with the header divider, got y " .. tostring(point[5]))
  end

  -- test_viewport_bottom_is_flush_with_composer_line
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", "Parent", nil)
    parent:SetSize(600, 420)
    local view = ConversationPane.Create(factory, parent, { displayName = "Arthas" }, { messages = {} })
    local expected = 420 - Theme.LAYOUT.HEADER_HEIGHT
    local height = view.transcript.scrollFrame:GetHeight()
    assert(height == expected, "viewport reaches the pane bottom, expected " .. expected .. ", got " .. tostring(height))
  end

  -- test_first_row_starts_pad_below_viewport_top
  do
    local transcript = makeTranscript(400, 120)
    TranscriptView.RenderTranscript(transcript, makeMessages(80))
    ScrollView.SetVerticalScroll(transcript, 0)
    local first = transcript._virtualState.rows[1]
    assert(first.offset - ScrollView.GetOffset(transcript) == PAD, "first row sits " .. PAD .. "px below the top, got " .. first.offset)
  end

  -- test_last_row_ends_pad_above_viewport_bottom_at_end
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(80)
    TranscriptView.RenderTranscript(transcript, messages)
    local rows = transcript._virtualState.rows
    local last = rows[#rows]
    local gap = viewportBottom(transcript) - (last.offset + last.height)
    assert(gap == PAD, "last row ends " .. PAD .. "px above the bottom, got " .. gap)
  end

  -- test_reaction_overhang_stays_pad_above_viewport_bottom
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(80)
    TranscriptView.RenderTranscript(transcript, messages)
    messages[80].reaction = { key = "heart" }
    TranscriptView.RenderTranscript(transcript, messages)
    local rows = transcript._virtualState.rows
    local last = rows[#rows]
    local gap = viewportBottom(transcript) - (last.offset + last.height)
    assert(gap == PAD, "reacted last row ends " .. PAD .. "px above the bottom, got " .. gap)
  end

  -- test_refresh_at_top_keeps_scroll_top
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(80)
    TranscriptView.RenderTranscript(transcript, messages)
    ScrollView.SetVerticalScroll(transcript, 0)
    messages[1].reaction = { key = "heart" }
    TranscriptView.RenderTranscript(transcript, messages)
    assert(ScrollView.GetOffset(transcript) == 0, "refresh at the top stays at the top, got " .. ScrollView.GetOffset(transcript))
  end

  -- test_jump_to_message_leaves_pad_above_target
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(80)
    TranscriptView.RenderTranscript(transcript, messages)
    TranscriptView.ScrollToReply(transcript, { id = "40", direction = messages[40].direction, snippet = messages[40].text })
    local row = transcript._virtualState.rows[40]
    local gap = row.offset - ScrollView.GetOffset(transcript)
    assert(gap == PAD, "jumped row sits " .. PAD .. "px below the top, got " .. gap)
  end
end
