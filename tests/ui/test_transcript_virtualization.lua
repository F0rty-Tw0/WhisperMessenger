local FakeUI = require("tests.helpers.fake_ui")
local Hyperlinks = require("WhisperMessenger.UI.Hyperlinks")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local ReactionAssets = require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local Fonts = require("WhisperMessenger.UI.Theme.Fonts")

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

local function countPooledWidgets(content)
  return #(content._activeFrames or {}) + #(content._freeFrames or {})
end

local function rowIndexAtOffset(rows, offset)
  local result = 1
  for index, row in ipairs(rows) do
    if row.offset > offset then
      break
    end
    result = index
  end
  return result
end

local function boundBubbleIndexes(content)
  local indexes = {}
  for _, frame in ipairs(content._activeFrames or {}) do
    if frame._textFS and frame._wmVirtualIndex then
      indexes[frame._wmVirtualIndex] = true
    end
  end
  return indexes
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
    assert(transcript._virtualLastIndex < 20, "test_scrolling_recycles_bindings_to_oldest_message: top viewport should not retain bottom rows")
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

    assert(ScrollView.GetOffset(transcript) == settledOffset, "test_ordinary_refresh_preserves_viewport: same-history refresh must not snap to end")
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

  -- test_measurement_collapse_clamps_anchor_delta
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(200)
    for _, message in ipairs(messages) do
      message.text = string.rep("https://example.com/path/", 12)
    end
    TranscriptView.RenderTranscript(transcript, messages)
    local anchorRow = transcript._virtualRows[100]
    ScrollView.SetVerticalScroll(transcript, anchorRow.offset + anchorRow.height - 1)

    anchorRow = transcript._virtualRows[100]
    assert(
      ScrollView.GetOffset(transcript) <= anchorRow.offset + anchorRow.height,
      "test_measurement_collapse_clamps_anchor_delta: retained offset must stay inside measured anchor"
    )
  end
  -- test_hyperlink_estimate_collapse_binds_final_viewport_range
  do
    local transcript = makeTranscript(400, 800)
    transcript.hasOverflow = true
    transcript.totalWidth = 400
    transcript.scrollFrame:SetSize(396, 800)
    transcript.content:SetSize(396, 800)
    local messages = makeMessages(200)
    local longLink = string.rep("https://example.com/very/long/path/", 12)
    for _, message in ipairs(messages) do
      message.text = longLink
    end

    TranscriptView.RenderTranscript(transcript, messages)

    local offset = ScrollView.GetOffset(transcript)
    local topIndex = rowIndexAtOffset(transcript._virtualRows, offset)
    local bottomIndex = rowIndexAtOffset(transcript._virtualRows, offset + transcript.viewportHeight - 1)
    local bound = boundBubbleIndexes(transcript.content)
    assert(bound[topIndex], "test_hyperlink_estimate_collapse_binds_final_viewport_range: top row must be bound")
    assert(bound[bottomIndex], "test_hyperlink_estimate_collapse_binds_final_viewport_range: bottom row must be bound")
    assert(
      transcript._virtualFirstIndex == math.max(topIndex - 2, 1),
      "test_hyperlink_estimate_collapse_binds_final_viewport_range: expected final leading overscan"
    )
    assert(
      transcript._virtualLastIndex == math.min(bottomIndex + 2, #transcript._virtualRows),
      "test_hyperlink_estimate_collapse_binds_final_viewport_range: expected final trailing overscan"
    )
  end

  -- test_font_geometry_revision_invalidates_offscreen_measurements
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(200)
    TranscriptView.RenderTranscript(transcript, messages)
    local lastRow = transcript._virtualRows[#messages]
    assert(lastRow.measured == true, "expected last row measured at initial end")
    ScrollView.SetVerticalScroll(transcript, 0)

    local originalOutline = Fonts.GetOutline()
    local changedOutline = originalOutline == "OUTLINE" and "THICKOUTLINE" or "OUTLINE"
    Fonts.SetOutline(changedOutline)
    TranscriptView.RenderTranscript(transcript, messages)
    local invalidated = lastRow.measured == false
    Fonts.SetOutline(originalOutline)

    assert(invalidated, "test_font_geometry_revision_invalidates_offscreen_measurements: offscreen row must invalidate")
  end

  -- test_reaction_badge_overflow_is_part_of_estimated_height
  do
    local message = {
      direction = "in",
      kind = "user",
      playerName = "Arthas",
      sentAt = 1,
      text = "reacted",
      reaction = { key = "heart" },
    }
    local withReaction = Layout.EstimateRowHeight(nil, message, 400, true)
    message.reaction = nil
    local withoutReaction = Layout.EstimateRowHeight(nil, message, 400, true)

    assert(
      withReaction == withoutReaction + ReactionAssets.GetBadgeOverflow(),
      "test_reaction_badge_overflow_is_part_of_estimated_height: expected badge overflow in row estimate"
    )
  end

  -- test_pool_stays_bounded_across_traversals_and_appends
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(200)
    TranscriptView.RenderTranscript(transcript, messages)

    for cycle = 1, 5 do
      ScrollView.SetVerticalScroll(transcript, 0)
      ScrollView.SetVerticalScroll(transcript, transcript._virtualRows[100].offset)
      ScrollView.SetVerticalScroll(transcript, ScrollView.GetRange(transcript))
      for _ = 1, 20 do
        local index = #messages + 1
        messages[index] = {
          direction = index % 2 == 0 and "out" or "in",
          kind = "user",
          playerName = "Arthas",
          sentAt = index,
          text = "appended " .. index,
        }
      end
      TranscriptView.RenderTranscript(transcript, messages)
    end

    local widgetCount = countPooledWidgets(transcript.content)
    assert(#messages == 300, "test_pool_stays_bounded_across_traversals_and_appends: expected repeated appends")
    assert(widgetCount < 60, "test_pool_stays_bounded_across_traversals_and_appends: widget pool grew to " .. widgetCount)
    assert(widgetCount * 4 < #messages, "test_pool_stays_bounded_across_traversals_and_appends: pool must not scale with history")
  end
end
