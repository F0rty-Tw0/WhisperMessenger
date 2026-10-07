-- Scrolling must only build the rows that enter the viewport. Rebuilding
-- every visible bubble on each wheel step made long channels (Trade, 500
-- messages) spike the CPU while scrolling.

local FakeUI = require("tests.helpers.fake_ui")
local BubbleFrame = require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local FramePool = require("WhisperMessenger.UI.ChatBubble.FramePool")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")

local LONG_TEXT = "WTS boost mythic plus keys tonight, cheap, whisper me for prices and times please"

-- Mixed lengths and senders: long rows are estimated taller than they
-- measure, so laying them out shifts every row below.
local function makeMessages(count)
  local messages = {}
  for index = 1, count do
    messages[index] = {
      direction = "in",
      kind = "user",
      playerName = index % 2 == 0 and "Arthas" or "Jaina",
      sentAt = index,
      text = index % 3 == 0 and LONG_TEXT or ("message " .. index),
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
  transcript.seenReceipts = false
  TranscriptSetup.ConfigureTranscript(factory, transcript, width)
  return transcript
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

local function bubbleTops(content)
  local result = {}
  for message, frame in pairs(bubbleByMessage(content)) do
    local _, _, _, _, y = frame:GetPoint(1)
    result[message] = y
  end
  return result
end

local function scrollUpUntilRangeMoves(transcript)
  local firstIndex = transcript._virtualFirstIndex
  local wheel = transcript.scrollFrame:GetScript("OnMouseWheel")
  for _ = 1, 50 do
    wheel(transcript.scrollFrame, 1)
    if transcript._virtualFirstIndex ~= firstIndex then
      return
    end
  end
  error("scroll never moved the visible range")
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

-- Every bubble sits where a from-scratch rebuild at the same offset puts it.
local function assertMatchesRebuild(transcript, messages, name)
  local reused = bubbleTops(transcript.content)
  local reusedOffset = ScrollView.GetOffset(transcript)

  TranscriptView.RenderTranscript(transcript, messages, TranscriptView.FORCE_RENDER)

  assert(ScrollView.GetOffset(transcript) == reusedOffset, name .. ": offset moved")
  local compared = 0
  for message, y in pairs(bubbleTops(transcript.content)) do
    assert(reused[message] ~= nil, name .. ": missing bubble for " .. message.text)
    assert(reused[message] == y, name .. ": " .. message.text .. " at " .. tostring(reused[message]) .. ", rebuild puts it at " .. y)
    compared = compared + 1
  end
  assert(compared > 0, name .. ": no bubbles compared")
end

return function()
  -- test_scroll_step_builds_only_entering_rows
  do
    local transcript = makeTranscript(400, 200)
    local messages = makeMessages(200)
    TranscriptView.RenderTranscript(transcript, messages)
    local before = bubbleByMessage(transcript.content)
    local oldFirst, oldLast = transcript._virtualFirstIndex, transcript._virtualLastIndex

    local builds = countBubbleBuilds(function()
      scrollUpUntilRangeMoves(transcript)
    end)

    local newFirst, newLast = transcript._virtualFirstIndex, transcript._virtualLastIndex
    local entering = 0
    for index = newFirst, newLast do
      if index < oldFirst or index > oldLast then
        entering = entering + 1
      end
    end
    assert(entering > 0 and entering < newLast - newFirst + 1, "test_scroll_step_builds_only_entering_rows: expected a partial range shift")
    assert(builds == entering, "test_scroll_step_builds_only_entering_rows: expected " .. entering .. " bubble builds, got " .. builds)
    local after = bubbleByMessage(transcript.content)
    for index = math.max(newFirst, oldFirst), math.min(newLast, oldLast) do
      local message = messages[index]
      assert(after[message] == before[message], "test_scroll_step_builds_only_entering_rows: row " .. index .. " lost its bubble")
    end
  end

  -- test_kept_rows_sit_where_a_full_rebuild_puts_them
  do
    local transcript = makeTranscript(400, 200)
    local messages = makeMessages(200)
    TranscriptView.RenderTranscript(transcript, messages)
    for _ = 1, 30 do
      scrollUpUntilRangeMoves(transcript)
    end
    assertMatchesRebuild(transcript, messages, "test_kept_rows_sit_where_a_full_rebuild_puts_them")
  end

  -- test_external_release_forces_a_fresh_build
  do
    local transcript = makeTranscript(400, 200)
    local messages = makeMessages(200)
    TranscriptView.RenderTranscript(transcript, messages)
    FramePool.releaseAll(transcript.content)

    scrollUpUntilRangeMoves(transcript)

    local bound = bubbleByMessage(transcript.content)
    for index = transcript._virtualFirstIndex, transcript._virtualLastIndex do
      assert(bound[messages[index]] ~= nil, "test_external_release_forces_a_fresh_build: row " .. index .. " has no bubble")
    end
  end

  -- test_new_message_while_scrolled_up_builds_nothing_on_screen
  do
    local transcript = makeTranscript(400, 200)
    local messages = makeMessages(200)
    TranscriptView.RenderTranscript(transcript, messages)
    for _ = 1, 10 do
      scrollUpUntilRangeMoves(transcript)
    end
    local before = bubbleByMessage(transcript.content)

    local builds = countBubbleBuilds(function()
      messages[#messages + 1] = { direction = "in", kind = "user", playerName = "Thrall", sentAt = 1000, text = "new line" }
      TranscriptView.RenderTranscript(transcript, messages)
    end)

    assert(builds == 0, "test_new_message_while_scrolled_up_builds_nothing_on_screen: expected 0 bubble builds, got " .. builds)
    for message, frame in pairs(bubbleByMessage(transcript.content)) do
      assert(before[message] == frame, "test_new_message_while_scrolled_up_builds_nothing_on_screen: " .. message.text .. " was rebuilt")
    end
    assertMatchesRebuild(transcript, messages, "test_new_message_while_scrolled_up_builds_nothing_on_screen")
  end

  -- test_history_cap_shift_keeps_on_screen_bubbles
  do
    local transcript = makeTranscript(400, 200)
    local messages = makeMessages(200)
    TranscriptView.RenderTranscript(transcript, messages)
    for _ = 1, 10 do
      scrollUpUntilRangeMoves(transcript)
    end

    local builds = countBubbleBuilds(function()
      table.remove(messages, 1)
      messages[#messages + 1] = { direction = "in", kind = "user", playerName = "Thrall", sentAt = 1000, text = "new line" }
      TranscriptView.RenderTranscript(transcript, messages)
    end)

    assert(builds == 0, "test_history_cap_shift_keeps_on_screen_bubbles: expected 0 bubble builds, got " .. builds)
    assertMatchesRebuild(transcript, messages, "test_history_cap_shift_keeps_on_screen_bubbles")
  end

  -- test_edited_message_on_screen_is_redrawn
  do
    local transcript = makeTranscript(400, 200)
    local messages = makeMessages(200)
    TranscriptView.RenderTranscript(transcript, messages)
    local edited = messages[transcript._virtualLastIndex - 1]

    local builds = countBubbleBuilds(function()
      edited.text = "edited body"
      TranscriptView.RenderTranscript(transcript, messages)
    end)

    assert(builds == 1, "test_edited_message_on_screen_is_redrawn: expected 1 bubble build, got " .. builds)
    local frame = bubbleByMessage(transcript.content)[edited]
    assert(frame and frame._textFS:GetText() == "edited body", "test_edited_message_on_screen_is_redrawn: new text not shown")
  end

  -- test_scrolling_keeps_icon_frames_out_of_label_roles
  -- An icon built on a recycled label frame pays for a new masked texture,
  -- the most expensive part of a bubble.
  do
    local transcript = makeTranscript(400, 200)
    local messages = makeMessages(200)
    -- Hours apart, so date separators also take frames from the pool.
    for index, message in ipairs(messages) do
      message.sentAt = index * 5000
    end
    TranscriptView.RenderTranscript(transcript, messages)
    local wheel = transcript.scrollFrame:GetScript("OnMouseWheel")
    for _ = 1, 200 do
      wheel(transcript.scrollFrame, 1)
    end

    local content = transcript.content
    for _, list in ipairs({ content._activeFrames, content._freeFrames }) do
      for _, frame in ipairs(list) do
        local mixed = frame._wmCircularIconTexture and (frame._wmSenderNameFS or frame._labelFS)
        assert(not mixed, "test_scrolling_keeps_icon_frames_out_of_label_roles: a pooled frame served as both icon and label")
      end
    end
  end
end
