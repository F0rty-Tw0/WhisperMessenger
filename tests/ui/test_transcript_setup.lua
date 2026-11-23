local FakeUI = require("tests.helpers.fake_ui")
local ScrollView = require("WhisperMessenger.UI.ScrollView")
local TranscriptView = require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local TranscriptSetup = require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")

return function()
  local function makeTranscript(factory, parentWidth)
    parentWidth = parentWidth or 600
    local parent = factory.CreateFrame("Frame", "Parent", nil)
    parent:SetSize(parentWidth, 420)

    local TRANSCRIPT_SCROLL_STEP = TranscriptView.TRANSCRIPT_SCROLL_STEP
    local transcript = ScrollView.Create(factory, parent, {
      width = parentWidth - 32,
      height = 350,
      step = TRANSCRIPT_SCROLL_STEP,
    })
    transcript.factory = factory
    return transcript
  end

  -- test_configure_creates_no_text_mirror

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    TranscriptSetup.ConfigureTranscript(factory, transcript, 600)

    assert(transcript.text == nil, "test_configure_creates_no_text_mirror: no hidden text box")
    assert(transcript.lines == nil, "test_configure_creates_no_text_mirror: no plain-text line copy")
  end

  -- test_scroll_wiring_preserves_original_mouse_wheel_handler

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local wheelOriginalCalled = false
    local wheelDelta

    transcript.scrollFrame:SetScript("OnMouseWheel", function(_self, delta)
      wheelOriginalCalled = true
      wheelDelta = delta
    end)

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600)

    local wheelHandler = transcript.scrollFrame:GetScript("OnMouseWheel")
    assert(type(wheelHandler) == "function", "test_scroll_wiring_preserves_original_mouse_wheel_handler: OnMouseWheel handler must exist")
    wheelHandler(transcript.scrollFrame, -1)
    assert(wheelOriginalCalled, "test_scroll_wiring_preserves_original_mouse_wheel_handler: original OnMouseWheel handler should be called")
    assert(
      wheelDelta == -1,
      "test_scroll_wiring_preserves_original_mouse_wheel_handler: original OnMouseWheel handler should receive the wheel delta"
    )
  end

  -- test_scroll_wiring_preserves_original_value_changed_handler

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local valueOriginalCalled
    local valueSeen

    transcript.scrollBar:SetScript("OnValueChanged", function(_self, value)
      valueOriginalCalled = true
      valueSeen = value
    end)

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600)

    local valueHandler = transcript.scrollBar:GetScript("OnValueChanged")
    assert(type(valueHandler) == "function", "test_scroll_wiring_preserves_original_value_changed_handler: OnValueChanged handler must exist")
    valueHandler(transcript.scrollBar, TranscriptView.TRANSCRIPT_SCROLL_STEP)
    assert(valueOriginalCalled, "test_scroll_wiring_preserves_original_value_changed_handler: original OnValueChanged handler should be called")
    assert(
      valueSeen == TranscriptView.TRANSCRIPT_SCROLL_STEP,
      "test_scroll_wiring_preserves_original_value_changed_handler: original OnValueChanged handler should receive the scroll value"
    )
  end
end
