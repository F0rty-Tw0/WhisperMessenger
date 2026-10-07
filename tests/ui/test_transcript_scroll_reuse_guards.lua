-- Guards that decide whether a row may keep its frames across a layout pass.
-- Keeping a row that should not be kept shares a pooled frame between two
-- rows, or leaves a stale read receipt on screen.

local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")

local function makeTranscript(seenReceipts)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 200)
  local transcript = ScrollView.Create(factory, parent, {
    width = 400,
    height = 200,
    step = TranscriptView.TRANSCRIPT_SCROLL_STEP,
  })
  transcript.factory = factory
  transcript.seenReceipts = seenReceipts
  TranscriptSetup.ConfigureTranscript(factory, transcript, 400)
  return transcript
end

local function wheelTicks(transcript, delta, count)
  local wheel = transcript.scrollFrame:GetScript("OnMouseWheel")
  for _ = 1, count do
    wheel(transcript.scrollFrame, delta)
  end
end

local function contains(list, value)
  for _, item in ipairs(list) do
    if item == value then
      return true
    end
  end
  return false
end

return function()
  -- test_row_scrolled_out_and_back_does_not_reclaim_released_frames
  do
    local transcript = makeTranscript(false)
    local messages = {}
    for index = 1, 200 do
      messages[index] =
        { direction = "in", kind = "user", playerName = index % 2 == 0 and "Arthas" or "Jaina", sentAt = index, text = "message " .. index }
    end
    TranscriptView.RenderTranscript(transcript, messages)
    wheelTicks(transcript, 1, 20)
    wheelTicks(transcript, -1, 20)
    wheelTicks(transcript, 1, 20)

    local content = transcript.content
    for _, frame in ipairs(content._freeFrames) do
      assert(
        not contains(content._activeFrames, frame),
        "test_row_scrolled_out_and_back_does_not_reclaim_released_frames: a frame is both active and free"
      )
    end
    local rows = transcript._virtualState.rows
    for index = transcript._virtualFirstIndex, transcript._virtualLastIndex do
      for _, frame in ipairs(rows[index].frames or {}) do
        assert(
          contains(content._activeFrames, frame),
          "test_row_scrolled_out_and_back_does_not_reclaim_released_frames: row " .. index .. " holds a released frame"
        )
      end
    end
  end

  -- test_seen_label_moves_off_a_kept_row
  do
    local transcript = makeTranscript(true)
    local messages = {
      { direction = "in", kind = "user", playerName = "Jaina", sentAt = 1, text = "hi" },
      { direction = "out", kind = "user", playerName = "Jaina", sentAt = 2, text = "older reply", seenAt = 3 },
      { direction = "in", kind = "user", playerName = "Jaina", sentAt = 4, text = "and?" },
      { direction = "out", kind = "user", playerName = "Jaina", sentAt = 5, text = "newer reply" },
    }
    TranscriptView.RenderTranscript(transcript, messages)
    messages[4].seenAt = 6
    TranscriptView.RenderTranscript(transcript, messages)

    local rows = transcript._virtualState.rows
    local shown = {}
    for _, frame in ipairs(transcript.content._activeFrames) do
      local seenFS = frame._wmSenderSeenFS
      if seenFS and seenFS:IsShown() then
        shown[#shown + 1] = frame
      end
    end
    assert(#shown == 1, "test_seen_label_moves_off_a_kept_row: expected 1 Seen label, got " .. #shown)
    assert(contains(rows[4].frames, shown[1]), "test_seen_label_moves_off_a_kept_row: Seen label is not on the newest reply")
  end
end
