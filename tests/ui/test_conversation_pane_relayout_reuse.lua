-- A height-only relayout (composer line wrap, vertical resize, a banner
-- showing above the composer) keeps the bubbles already on screen instead
-- of rebuilding every one. A width or theme change still rebuilds them.

local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")

local PANE_WIDTH = 600
local PANE_HEIGHT = 420
local SHORTER = PANE_HEIGHT - 40
local MESSAGE_COUNT = 80
-- Just overflows the pane while every row is still on screen.
local SHORT_HISTORY = 10

local function makeMessages(count)
  local messages = {}
  for index = 1, count do
    messages[index] = { direction = "in", kind = "user", playerName = "Arthas", sentAt = index, text = "line " .. index }
  end
  return messages
end

local function makePane(count)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "Parent", nil)
  parent:SetSize(PANE_WIDTH, PANE_HEIGHT)
  local contact = { conversationKey = "me::WOW::arthas", displayName = "Arthas", channel = "WOW" }
  local view = ConversationPane.Create(factory, parent, contact, { messages = makeMessages(count or MESSAGE_COUNT) })
  -- Size the transcript from the Relayout height, not the fake pane frame.
  view.frame.height = nil
  ConversationPane.Relayout(view, PANE_WIDTH, PANE_HEIGHT)
  assert(view.transcript.hasOverflow == true, "setup: the history overflows the transcript")
  return view
end

local function bubbleByMessage(content)
  local result = {}
  for _, frame in ipairs(content._activeFrames or {}) do
    if frame._textFS and frame._wmMessage then
      result[frame._wmMessage] = frame
    end
  end
  return result
end

local function countBubbleBuilds(fn)
  local original = BubbleFrame.CreateBubble
  local calls = 0
  ---@diagnostic disable-next-line: duplicate-set-field
  BubbleFrame.CreateBubble = function(...)
    calls = calls + 1
    return original(...)
  end
  local ok, err = pcall(fn)
  BubbleFrame.CreateBubble = original
  if not ok then
    error(err)
  end
  return calls
end

local function visibleRowCount(transcript)
  return transcript._virtualLastIndex - transcript._virtualFirstIndex + 1
end

-- Every message bound before and after fn keeps the same bubble frame, and
-- only messages that newly entered the viewport were built.
local function assertKeepsBubbles(view, fn, name)
  local t = view.transcript
  local before = bubbleByMessage(t.content)
  local builds = countBubbleBuilds(fn)
  local entering, kept = 0, 0
  for message, frame in pairs(bubbleByMessage(t.content)) do
    if before[message] == nil then
      entering = entering + 1
    else
      assert(before[message] == frame, name .. ": " .. message.text .. " got a new bubble frame")
      kept = kept + 1
    end
  end
  assert(kept > 0, name .. ": no bubble stayed in view")
  assert(builds == entering, name .. ": expected " .. entering .. " bubble builds, got " .. builds)
end

-- The reused layout matches a from-scratch rebuild: same scroll range,
-- offset and bubble positions.
local function assertMatchesRebuild(view, name)
  local t = view.transcript
  local range, offset = ScrollView.GetRange(t), ScrollView.GetOffset(t)
  local tops = {}
  for message, frame in pairs(bubbleByMessage(t.content)) do
    local _, _, _, _, y = frame:GetPoint(1)
    tops[message] = y
  end
  TranscriptView.RenderTranscript(t, t._allMessages, TranscriptView.FORCE_RENDER)
  assert(ScrollView.GetRange(t) == range, name .. ": range " .. range .. ", rebuild gives " .. ScrollView.GetRange(t))
  assert(ScrollView.GetOffset(t) == offset, name .. ": offset " .. offset .. ", rebuild gives " .. ScrollView.GetOffset(t))
  for message, frame in pairs(bubbleByMessage(t.content)) do
    local _, _, _, _, y = frame:GetPoint(1)
    assert(tops[message] == y, name .. ": " .. message.text .. " at " .. tostring(tops[message]) .. ", rebuild puts it at " .. y)
  end
end

return function()
  -- test_height_only_relayout_at_end_keeps_bubbles
  do
    local view = makePane()
    assert(TranscriptView.IsAtEnd(view.transcript), "setup: pane opens at the newest message")

    assertKeepsBubbles(view, function()
      ConversationPane.Relayout(view, PANE_WIDTH, SHORTER)
    end, "test_height_only_relayout_at_end_keeps_bubbles")

    assert(TranscriptView.IsAtEnd(view.transcript), "test_height_only_relayout_at_end_keeps_bubbles: still at the newest message")
    assertMatchesRebuild(view, "test_height_only_relayout_at_end_keeps_bubbles")
  end

  -- test_height_only_relayout_mid_transcript_keeps_bubbles
  do
    local view = makePane()
    local t = view.transcript
    ScrollView.SetVerticalScroll(t, t._virtualState.rows[30].offset)

    assertKeepsBubbles(view, function()
      ConversationPane.Relayout(view, PANE_WIDTH, SHORTER)
    end, "test_height_only_relayout_mid_transcript_keeps_bubbles")

    assert(not TranscriptView.IsAtEnd(t), "test_height_only_relayout_mid_transcript_keeps_bubbles: stays mid-transcript")
    assertMatchesRebuild(view, "test_height_only_relayout_mid_transcript_keeps_bubbles")
  end

  -- test_taller_pane_hides_scrollbar_when_rows_stay_the_same
  -- Every row is already on screen, so the visible range does not change,
  -- but the overflow and its scrollbar must still go away.
  do
    local view = makePane(SHORT_HISTORY)
    local t = view.transcript
    assert(t._virtualFirstIndex == 1 and t._virtualLastIndex == SHORT_HISTORY, "setup: every row is on screen")
    ScrollView.SetVerticalScroll(t, 0)

    ConversationPane.Relayout(view, PANE_WIDTH, PANE_HEIGHT + 200)

    assert(t.hasOverflow == false, "test_taller_pane_hides_scrollbar_when_rows_stay_the_same: overflow cleared")
    assert(t.scrollBar.shown == false, "test_taller_pane_hides_scrollbar_when_rows_stay_the_same: scrollbar hidden")
  end

  -- test_bottom_banner_keeps_bubbles
  do
    local view = makePane()
    local heightBefore = view.transcript.viewportHeight

    assertKeepsBubbles(view, function()
      ConversationPane.SetNotice(view, "Chat is paused")
    end, "test_bottom_banner_keeps_bubbles")

    assert(view.transcript.viewportHeight < heightBefore, "test_bottom_banner_keeps_bubbles: the banner shrinks the transcript")
    assert(TranscriptView.IsAtEnd(view.transcript), "test_bottom_banner_keeps_bubbles: still at the newest message")
    assertMatchesRebuild(view, "test_bottom_banner_keeps_bubbles")
  end

  -- test_width_change_rebuilds_bubbles
  do
    local view = makePane()
    local builds = countBubbleBuilds(function()
      ConversationPane.Relayout(view, PANE_WIDTH - 100, PANE_HEIGHT)
    end)
    local visible = visibleRowCount(view.transcript)
    assert(builds >= visible, "test_width_change_rebuilds_bubbles: expected at least " .. visible .. " builds, got " .. builds)
  end

  -- test_theme_refresh_rebuilds_bubbles
  do
    local view = makePane()
    local before = bubbleByMessage(view.transcript.content)
    local builds = countBubbleBuilds(function()
      view.refreshTheme()
    end)
    local visible = visibleRowCount(view.transcript)
    assert(builds >= visible, "test_theme_refresh_rebuilds_bubbles: expected at least " .. visible .. " builds, got " .. builds)
    for message in pairs(bubbleByMessage(view.transcript.content)) do
      assert(before[message] ~= nil, "test_theme_refresh_rebuilds_bubbles: same rows stay in view")
    end
  end
end
