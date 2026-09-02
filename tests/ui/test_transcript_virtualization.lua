local FakeUI = require("tests.helpers.fake_ui")
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")

local function makeMessages(count)
  local messages = {}
  for index = 1, count do
    messages[index] = {
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
  local transcript = ScrollView.Create(factory, parent, {
    width = width,
    height = height,
    step = TranscriptView.TRANSCRIPT_SCROLL_STEP,
  })
  transcript.factory = factory
  TranscriptSetup.ConfigureTranscript(factory, transcript, width)
  return transcript
end

local function countBubbleFrames(content)
  local count = 0
  for _, frames in ipairs({ content._activeFrames or {}, content._freeFrames or {} }) do
    for _, frame in ipairs(frames) do
      if frame._textFS then
        count = count + 1
      end
    end
  end
  return count
end

return function()
  -- test_full_history_uses_bounded_visible_bindings
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(200)
    local originalFormat = Hyperlinks.FormatTextForDisplay
    local formatCalls = 0
    Hyperlinks.FormatTextForDisplay = function(text)
      formatCalls = formatCalls + 1
      return originalFormat(text)
    end

    TranscriptView.RenderTranscript(transcript, messages)
    local initialFormatCalls = formatCalls
    formatCalls = 0
    TranscriptView.RenderTranscript(transcript, messages)
    local refreshFormatCalls = formatCalls

    Hyperlinks.FormatTextForDisplay = originalFormat
    local rows = transcript._virtualRows
    assert(type(rows) == "table", "test_full_history_uses_bounded_visible_bindings: expected full row metadata")
    assert(#rows == 200, "test_full_history_uses_bounded_visible_bindings: expected metadata for all 200 messages")
    assert(
      transcript._virtualLastIndex - transcript._virtualFirstIndex + 1 < 20,
      "test_full_history_uses_bounded_visible_bindings: expected only viewport rows plus small overscan"
    )
    assert(initialFormatCalls < 20, "test_full_history_uses_bounded_visible_bindings: initial render must not format offscreen messages")
    assert(refreshFormatCalls < 20, "test_full_history_uses_bounded_visible_bindings: ordinary refresh must not format offscreen messages")
    assert(countBubbleFrames(transcript.content) < 20, "test_full_history_uses_bounded_visible_bindings: bubble pool must stay bounded")
    for index, row in ipairs(rows) do
      assert(row.message == messages[index], "test_full_history_uses_bounded_visible_bindings: row message mismatch at " .. index)
      if index > 1 then
        assert(
          row.offset == rows[index - 1].offset + rows[index - 1].height,
          "test_full_history_uses_bounded_visible_bindings: row offsets must be contiguous"
        )
      end
    end
  end

  -- test_scrolling_recycles_bindings_to_oldest_message
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(200)
    TranscriptView.RenderTranscript(transcript, messages)
    local bubbleCount = countBubbleFrames(transcript.content)

    ScrollView.SetVerticalScroll(transcript, 0)

    assert(transcript._virtualFirstIndex == 1, "test_scrolling_recycles_bindings_to_oldest_message: first row should bind at top")
    assert(
      transcript._virtualLastIndex < 20,
      "test_scrolling_recycles_bindings_to_oldest_message: top viewport should not retain bottom rows"
    )
    assert(
      countBubbleFrames(transcript.content) == bubbleCount,
      "test_scrolling_recycles_bindings_to_oldest_message: scrolling should reuse bounded bubble frames"
    )
    local foundOldest = false
    for _, frame in ipairs(transcript.content._activeFrames or {}) do
      if frame._textFS and frame._textFS:GetText() == "message 1" then
        foundOldest = true
      end
    end
    assert(foundOldest, "test_scrolling_recycles_bindings_to_oldest_message: oldest message should remain reachable")
  end

  -- test_ordinary_refresh_preserves_viewport
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(80)
    TranscriptView.RenderTranscript(transcript, messages)
    local middleOffset = transcript._virtualRows[30].offset + 3
    ScrollView.SetVerticalScroll(transcript, middleOffset)
    local settledOffset = ScrollView.GetOffset(transcript)

    TranscriptView.RenderTranscript(transcript, messages)

    assert(
      ScrollView.GetOffset(transcript) == settledOffset,
      "test_ordinary_refresh_preserves_viewport: same-history refresh must not snap to end"
    )
  end

  -- test_append_preserves_end_or_scrolled_viewport
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(80)
    TranscriptView.RenderTranscript(transcript, messages)
    messages[#messages + 1] = makeMessages(1)[1]
    messages[#messages].text = "appended at end"
    messages[#messages].sentAt = 81

    TranscriptView.RenderTranscript(transcript, messages)

    assert(
      ScrollView.GetOffset(transcript) == ScrollView.GetRange(transcript),
      "test_append_preserves_end_or_scrolled_viewport: append at end should remain snapped to end"
    )

    local middleOffset = transcript._virtualRows[30].offset + 2
    ScrollView.SetVerticalScroll(transcript, middleOffset)
    local settledOffset = ScrollView.GetOffset(transcript)
    messages[#messages + 1] = makeMessages(1)[1]
    messages[#messages].text = "appended while reading"
    messages[#messages].sentAt = 82

    TranscriptView.RenderTranscript(transcript, messages)

    assert(
      ScrollView.GetOffset(transcript) == settledOffset,
      "test_append_preserves_end_or_scrolled_viewport: append while scrolled up should preserve viewport"
    )
  end
end
