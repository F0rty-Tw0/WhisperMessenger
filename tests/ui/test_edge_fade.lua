local ConversationPane = require("WhisperMessenger.UI.ConversationPane")
local EdgeFade = require("WhisperMessenger.UI.ConversationPane.EdgeFade")
local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")

-- Rows sliding out of the transcript turn transparent near the edges instead
-- of being cut with a hard line; rows fully inside stay opaque.
local VIEWPORT_HEIGHT = 200

local function makeMessages(count)
  local messages = {}
  for index = 1, count do
    messages[index] = {
      direction = index % 3 == 0 and "out" or "in",
      kind = "user",
      playerName = index % 5 == 0 and "Jaina" or "Arthas",
      sentAt = index,
      text = "message " .. index,
    }
  end
  return messages
end

local function makeFadedTranscript(messages)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, VIEWPORT_HEIGHT)
  local transcript = ScrollView.Create(factory, parent, { width = 400, height = VIEWPORT_HEIGHT, step = TranscriptView.TRANSCRIPT_SCROLL_STEP })
  transcript.factory = factory
  TranscriptSetup.ConfigureTranscript(factory, transcript, 400)
  local fade = EdgeFade.Attach(factory, parent, transcript)
  TranscriptView.RenderTranscript(transcript, messages)
  return transcript, fade
end

local function row(transcript, index)
  return transcript._virtualState.rows[index]
end

-- Every frame the row laid out must carry one shared alpha.
local function rowAlpha(transcript, index)
  local target = row(transcript, index)
  local active = transcript.content._activeFrames
  assert(target.frameFirst and target.frameLast >= target.frameFirst, "row " .. index .. " is laid out")
  local alpha = active[target.frameFirst]:GetAlpha() or 1
  for frameIndex = target.frameFirst + 1, target.frameLast do
    assert((active[frameIndex]:GetAlpha() or 1) == alpha, "row " .. index .. " pieces fade together")
  end
  return alpha
end

local function near(actual, expected)
  return math.abs(actual - expected) < 0.001
end

-- Scrolls so the row's bottom sits `visible` px below the viewport top.
local function showBottomOfRow(transcript, index, visible)
  local target = row(transcript, index)
  ScrollView.SetVerticalScroll(transcript, target.offset + target.height - visible)
end

-- Scrolls so the row's top sits `visible` px above the viewport bottom.
local function showTopOfRow(transcript, index, visible)
  ScrollView.SetVerticalScroll(transcript, row(transcript, index).offset - (VIEWPORT_HEIGHT - visible))
end

return function()
  local distance = EdgeFade.FADE_DISTANCE

  -- test_fade_distance_keeps_resting_rows_opaque
  do
    assert(distance >= 24 and distance <= 32, "fade distance in the 24-32px band, got " .. tostring(distance))
  end

  -- test_row_fully_inside_is_opaque
  do
    local transcript = makeFadedTranscript(makeMessages(80))
    ScrollView.SetVerticalScroll(transcript, row(transcript, 40).offset - 60)
    assert(rowAlpha(transcript, 40) == 1, "row inside the viewport is opaque")
  end

  -- test_row_leaving_top_edge_fades
  do
    local transcript = makeFadedTranscript(makeMessages(80))
    showBottomOfRow(transcript, 40, distance / 2)
    assert(near(rowAlpha(transcript, 40), 0.5), "half the fade distance left -> half transparent, got " .. rowAlpha(transcript, 40))
    showBottomOfRow(transcript, 40, 1)
    assert(rowAlpha(transcript, 40) < 0.1, "almost gone past the top -> nearly invisible, got " .. rowAlpha(transcript, 40))
  end

  -- test_row_leaving_bottom_edge_fades
  do
    local transcript = makeFadedTranscript(makeMessages(80))
    showTopOfRow(transcript, 40, distance / 2)
    assert(near(rowAlpha(transcript, 40), 0.5), "half the fade distance showing -> half transparent, got " .. rowAlpha(transcript, 40))
    showTopOfRow(transcript, 40, 1)
    assert(rowAlpha(transcript, 40) < 0.1, "barely in at the bottom -> nearly invisible, got " .. rowAlpha(transcript, 40))
  end

  -- test_first_row_at_scroll_top_is_opaque
  do
    local transcript = makeFadedTranscript(makeMessages(80))
    ScrollView.SetVerticalScroll(transcript, 0)
    assert(rowAlpha(transcript, 1) == 1, "oldest message at rest is never dimmed")
  end

  -- test_last_row_at_end_is_opaque
  do
    local messages = makeMessages(80)
    local transcript = makeFadedTranscript(messages)
    assert(rowAlpha(transcript, #messages) == 1, "newest message at rest is never dimmed")
  end

  -- test_short_system_rows_at_rest_are_opaque
  do
    local messages = makeMessages(80)
    messages[1] = { kind = "system", direction = "in", sentAt = 1, text = "x" }
    messages[80] = { kind = "system", direction = "in", sentAt = 80, text = "y" }
    local transcript = makeFadedTranscript(messages)
    assert(rowAlpha(transcript, 80) == 1, "short last row at the end is opaque")
    ScrollView.SetVerticalScroll(transcript, 0)
    assert(rowAlpha(transcript, 1) == 1, "short first row at the top is opaque")
  end

  -- test_relayout_in_place_keeps_fade
  do
    local messages = makeMessages(80)
    local transcript = makeFadedTranscript(messages)
    showBottomOfRow(transcript, 40, distance / 2)
    TranscriptView.RenderTranscript(transcript, messages, TranscriptView.FORCE_RENDER)
    assert(near(rowAlpha(transcript, 40), 0.5), "re-laid-out rows get their fade again")
  end

  -- test_reused_pooled_frame_returns_to_opaque
  do
    local transcript = makeFadedTranscript(makeMessages(80))
    showBottomOfRow(transcript, 40, 1)
    ScrollView.SetVerticalScroll(transcript, ScrollView.GetRange(transcript))
    local offset = ScrollView.GetOffset(transcript)
    local state = transcript._virtualState
    for index = state.firstIndex, state.lastIndex do
      local target = row(transcript, index)
      local top = target.offset - offset
      if top >= 0 and top + target.height <= VIEWPORT_HEIGHT then
        assert(rowAlpha(transcript, index) == 1, "reused frames for row " .. index .. " are opaque")
      end
    end
    for _, frame in ipairs(transcript.content._freeFrames) do
      assert((frame:GetAlpha() or 1) == 1, "released frames carry no stale fade")
    end
  end

  -- test_header_and_composer_cast_shadows_only_over_scrolled_content
  do
    local transcript, fade = makeFadedTranscript(makeMessages(80))
    assert(fade.topShadow.shown == true, "older messages under the header -> header shadow")
    assert(fade.bottomShadow.shown == false, "at the newest message -> no composer shadow")
    ScrollView.SetVerticalScroll(transcript, 0)
    assert(fade.topShadow.shown == false and fade.bottomShadow.shown == true, "at the top -> composer shadow only")
    local color = fade.topShadow.color
    assert(color[1] == 0 and color[2] == 0 and color[3] == 0, "shadow is a dark gradient, not the theme background")
  end

  -- test_shadows_span_the_whole_pane_without_moving_content
  do
    local transcript, fade = makeFadedTranscript(makeMessages(80))
    local overlay = fade.topShadow.parent
    local anchoredTo = {}
    for _, point in ipairs(overlay.points) do
      anchoredTo[point[1]] = point[2]
    end
    assert(anchoredTo.LEFT == transcript.scrollFrame.parent and anchoredTo.RIGHT == transcript.scrollFrame.parent, "full pane width")
    assert(overlay:GetFrameLevel() > transcript.scrollFrame:GetFrameLevel(), "drawn over the messages")
    assert(transcript.viewportHeight == VIEWPORT_HEIGHT, "viewport size unchanged")
  end

  -- test_both_skins_fade_the_transcript
  do
    local factory = FakeUI.NewFactory()
    local function pane(nativeChrome)
      local host = factory.CreateFrame("Frame", nil, nil)
      host:SetSize(600, 420)
      return ConversationPane.Create(factory, host, nil, nil, { hideEmptyHeader = nativeChrome, nativeChrome = nativeChrome })
    end
    assert(pane(false).edgeFade ~= nil, "modern skin fades the transcript edges")
    assert(pane(true).edgeFade ~= nil, "Native WoW HUD fades too: no painted colour to clash")
  end
end
