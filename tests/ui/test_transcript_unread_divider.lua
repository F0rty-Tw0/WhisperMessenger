local FakeUI = require("tests.helpers.fake_ui")
local DateSeparator = require("WhisperMessenger.UI.ChatBubble.DateSeparator")
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local Theme = require("WhisperMessenger.UI.Theme")
local TranscriptRows = require("WhisperMessenger.UI.ConversationPane.TranscriptRows")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")

local function makeMessages(count)
  local messages = {}
  for index = 1, count do
    messages[index] = { direction = "in", kind = "user", playerName = "Arthas", sentAt = index, text = "message " .. index }
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

local function findDivider(content)
  for _, frame in ipairs(content._activeFrames or {}) do
    if frame._labelFS and frame._labelFS:GetText() == "New messages" then
      return frame
    end
  end
  return nil
end

local function render(transcript, messages, dividerMessage)
  transcript.unreadDividerMessage = dividerMessage
  TranscriptView.RenderTranscript(transcript, messages)
end

return function()
  -- test_new_messages_separator_reuses_date_separator_look
  do
    local factory = FakeUI.NewFactory()
    local parent = factory.CreateFrame("Frame", nil, nil)
    local separator = DateSeparator.CreateNewMessagesSeparator(factory, parent, 400)
    assert(separator.height == Theme.LAYOUT.DATE_SEPARATOR_HEIGHT, "same height as a date separator")
    assert(separator.frame._labelFS:GetText() == "New messages", "labelled New messages")
    assert(separator.frame._lineLeft ~= nil and separator.frame._lineRight ~= nil, "same divider lines")
    local accent = Theme.COLORS.accent
    local color = separator.frame._labelFS.textColor
    assert(color[1] == accent[1] and color[2] == accent[2] and color[3] == accent[3], "label uses the accent color")
  end

  -- test_row_estimate_reserves_divider_height
  do
    local messages = makeMessages(2)
    local plain = Layout.EstimateRowHeight(messages[1], messages[2], 400, false)
    local withDivider = Layout.EstimateRowHeight(messages[1], messages[2], 400, false, true)
    assert(withDivider > plain, "divider row is estimated taller")
  end

  -- test_divider_leaves_only_small_gap_before_message
  do
    local messages = {
      { direction = "out", kind = "user", playerName = "Me", sentAt = 1, text = "hi" },
      { direction = "in", kind = "user", playerName = "Arthas", sentAt = 2, text = "hey" },
    }
    local function totalHeight(dividerMessage)
      local factory = FakeUI.NewFactory()
      local content = factory.CreateFrame("Frame", nil, nil)
      Layout.LayoutMessages(factory, content, messages, 400, { unreadDividerMessage = dividerMessage })
      local rows = content._wmLayoutRows
      return rows[2].offset + rows[2].height
    end
    -- The divider replaces the usual gap between senders with the small
    -- in-group gap, so it adds its own height and nothing more.
    local expected = Theme.LAYOUT.DATE_SEPARATOR_HEIGHT + Theme.LAYOUT.BUBBLE_SPACING - Theme.LAYOUT.BUBBLE_GROUP_SPACING
    local laidOut = totalHeight(messages[2]) - totalHeight(nil)
    assert(laidOut == expected, "divider adds " .. expected .. "px, got " .. laidOut)
    local estimated = Layout.EstimateRowHeight(messages[1], messages[2], 400, false, true)
      - Layout.EstimateRowHeight(messages[1], messages[2], 400, false)
    assert(estimated == expected, "estimate matches layout, got " .. estimated)
  end

  -- test_short_unread_block_keeps_jump_to_latest
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(80)
    render(transcript, messages, messages[80])
    assert(ScrollView.GetOffset(transcript) == ScrollView.GetRange(transcript), "short unread block still opens at the latest message")
    assert(findDivider(transcript.content) ~= nil, "divider rendered above the first unread message")
  end

  -- test_tall_unread_block_opens_at_divider
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(80)
    render(transcript, messages, messages[40])
    local row = transcript._virtualState.rows[40]
    assert(
      ScrollView.GetOffset(transcript) == row.offset - TranscriptRows.CONTENT_PAD,
      "tall unread block opens with the divider at the top, got " .. tostring(ScrollView.GetOffset(transcript))
    )
    local divider = findDivider(transcript.content)
    assert(divider ~= nil, "divider rendered")
  end

  -- test_divider_appearing_on_open_transcript_positions_once
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(80)
    render(transcript, messages, nil)
    render(transcript, messages, messages[40])
    local dividerOffset = transcript._virtualState.rows[40].offset - TranscriptRows.CONTENT_PAD
    assert(ScrollView.GetOffset(transcript) == dividerOffset, "a newly captured divider repositions the view")

    local readingOffset = transcript._virtualState.rows[60].offset
    ScrollView.SetVerticalScroll(transcript, readingOffset)
    local settled = ScrollView.GetOffset(transcript)
    render(transcript, messages, messages[40])
    assert(ScrollView.GetOffset(transcript) == settled, "later refreshes keep the reader's position")
  end

  -- test_divider_removed_when_cleared
  do
    local transcript = makeTranscript(400, 120)
    local messages = makeMessages(10)
    render(transcript, messages, messages[9])
    assert(findDivider(transcript.content) ~= nil, "divider shown")
    render(transcript, messages, nil)
    assert(findDivider(transcript.content) == nil, "divider gone once cleared")
  end
end
