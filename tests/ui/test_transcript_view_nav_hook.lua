-- TranscriptView tells the WoW: Forever gamepad UI when bubbles were laid
-- out, so new messages get their stops and X context (GamepadTranscript).

local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")

local function makeMessages(count)
  local messages = {}
  for index = 1, count do
    messages[index] = { direction = "in", kind = "user", playerName = "Arthas", sentAt = index, text = "message " .. index }
  end
  return messages
end

local function makeTranscript()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", nil, nil)
  parent:SetSize(400, 300)
  local transcript = ScrollView.Create(factory, parent, { width = 400, height = 300, step = TranscriptView.TRANSCRIPT_SCROLL_STEP })
  transcript.factory = factory
  TranscriptSetup.ConfigureTranscript(factory, transcript, 400)
  return transcript
end

local function counting(transcript)
  local counter = { n = 0 }
  transcript.onNavTargetsChanged = function()
    counter.n = counter.n + 1
  end
  return counter
end

return function()
  -- test_render_reports_new_targets_once
  do
    local transcript = makeTranscript()
    local counter = counting(transcript)
    TranscriptView.RenderTranscript(transcript, makeMessages(1))
    assert(counter.n == 1, "one report per render, got " .. counter.n)
  end

  -- test_viewport_rerender_reports_new_targets
  do
    local transcript = makeTranscript()
    local messages = makeMessages(200)
    TranscriptView.RenderTranscript(transcript, messages)
    local counter = counting(transcript)
    transcript._renderingViewport = true
    ScrollView.SetVerticalScroll(transcript, 0)
    transcript._renderingViewport = nil
    assert(TranscriptView.RefreshViewport(transcript) == true, "scrolling to the top binds other rows")
    assert(counter.n == 1, "the viewport re-render reports once, got " .. counter.n)
    assert(TranscriptView.RefreshViewport(transcript) == false and counter.n == 1, "no new rows, no report")
  end

  -- test_render_without_a_hook_still_works
  do
    local transcript = makeTranscript()
    TranscriptView.RenderTranscript(transcript, makeMessages(1))
    assert(transcript._virtualState ~= nil, "rendered")
  end
end
