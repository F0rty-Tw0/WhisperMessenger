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

  -- Stub ConversationPane for tests (no circular require)
  local function makeConversationPaneStub()
    return {
      HasMore = function(_transcript)
        return false
      end,
      LoadMore = function(_transcript) end,
    }
  end

  -------------------------------------------------------------------------
  -- test_configure_creates_edit_box
  -------------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    assert(transcript.text ~= nil, "test_configure_creates_edit_box: transcript.text should be created")
  end

  -------------------------------------------------------------------------
  -- test_edit_box_is_multiline
  -------------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    assert(transcript.text.multiline == true, "test_edit_box_is_multiline: SetMultiLine(true) should be called")
  end

  -------------------------------------------------------------------------
  -- test_edit_box_auto_focus_disabled
  -------------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    assert(
      transcript.text.autoFocus == false,
      "test_edit_box_auto_focus_disabled: SetAutoFocus(false) should be called"
    )
  end

  -------------------------------------------------------------------------
  -- test_edit_box_hyperlinks_enabled
  -------------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    assert(
      transcript.text.hyperlinksEnabled == true,
      "test_edit_box_hyperlinks_enabled: SetHyperlinksEnabled(true) should be called"
    )
  end

  -------------------------------------------------------------------------
  -- test_initial_layout_called
  -------------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    -- After ConfigureTranscript, transcript.text should exist and have empty text
    assert(transcript.text ~= nil, "test_initial_layout_called: transcript.text must exist after configure")
    assert(
      transcript.text.text == "" or transcript.text.text == nil,
      "test_initial_layout_called: transcript.text should be set to empty string"
    )
  end

  -------------------------------------------------------------------------
  -- test_scroll_wiring_preserves_original_handler
  -------------------------------------------------------------------------
  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    -- Pre-install an original OnMouseWheel handler
    local originalCalled = false
    transcript.scrollFrame:SetScript("OnMouseWheel", function(_self, _delta)
      originalCalled = true
    end)

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    -- Fire the new OnMouseWheel handler
    local handler = transcript.scrollFrame:GetScript("OnMouseWheel")
    assert(
      type(handler) == "function",
      "test_scroll_wiring_preserves_original_handler: OnMouseWheel handler must exist"
    )
    handler(transcript.scrollFrame, -1)
    assert(
      originalCalled,
      "test_scroll_wiring_preserves_original_handler: original OnMouseWheel handler should be called"
    )
  end
end
