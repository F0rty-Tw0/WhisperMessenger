local FakeUI = require("tests.helpers.fake_ui")
local ManualCopyCapture = require("tests.helpers.manual_copy_capture")
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

  -- test_configure_creates_edit_box

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    TranscriptSetup.ConfigureTranscript(factory, transcript, 600)

    assert(transcript.text ~= nil, "test_configure_creates_edit_box: transcript.text should be created")
  end

  -- test_edit_box_is_multiline

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    TranscriptSetup.ConfigureTranscript(factory, transcript, 600)

    assert(transcript.text.multiline == true, "test_edit_box_is_multiline: SetMultiLine(true) should be called")
  end

  -- test_edit_box_auto_focus_disabled

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    TranscriptSetup.ConfigureTranscript(factory, transcript, 600)

    assert(transcript.text.autoFocus == false, "test_edit_box_auto_focus_disabled: SetAutoFocus(false) should be called")
  end

  -- test_edit_box_hyperlinks_enabled

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    TranscriptSetup.ConfigureTranscript(factory, transcript, 600)

    assert(transcript.text.hyperlinksEnabled == true, "test_edit_box_hyperlinks_enabled: SetHyperlinksEnabled(true) should be called")
  end

  -- test_url_hyperlink_click_avoids_protected_launch_and_copies_link

  ManualCopyCapture.With(function(copied)
    local savedExternalEventURL = _G.C_ExternalEventURL
    local savedLaunchURL = _G.LaunchURL

    local launchAttempted = false

    _G.C_ExternalEventURL = {
      LaunchURL = function()
        launchAttempted = true
      end,
    }
    _G.LaunchURL = function()
      launchAttempted = true
    end

    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    TranscriptSetup.ConfigureTranscript(factory, transcript, 600)
    transcript.text.scripts.OnHyperlinkClick(
      transcript.text,
      "addon:WhisperMessenger:url:https://example.com/help",
      "https://example.com/help",
      "LeftButton"
    )

    assert(launchAttempted == false, "expected transcript URL click to avoid protected LaunchURL APIs")
    assert(copied.text == "https://example.com/help", "expected transcript URL click to copy URL as safe fallback")

    _G.C_ExternalEventURL = savedExternalEventURL
    _G.LaunchURL = savedLaunchURL
  end)

  -- test_transcript_link_clicks_reach_blizzard_chat_handler
  do
    local savedMixin = rawget(_G, "ChatFrameMixin")
    local clicked = nil
    rawset(_G, "ChatFrameMixin", {
      OnHyperlinkClick = function(_self, link)
        clicked = link
      end,
    })
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    TranscriptSetup.ConfigureTranscript(factory, transcript, 600)
    transcript.text.scripts.OnHyperlinkClick(transcript.text, "trade:Player-1:2259:171", "[Tailoring]", "LeftButton")
    rawset(_G, "ChatFrameMixin", savedMixin)

    assert(clicked == "trade:Player-1:2259:171", "transcript link clicks should reach Blizzard's chat click handler")
  end

  -- test_initial_layout_called

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    TranscriptSetup.ConfigureTranscript(factory, transcript, 600)

    -- After ConfigureTranscript, transcript.text should exist and have empty text
    assert(transcript.text ~= nil, "test_initial_layout_called: transcript.text must exist after configure")
    assert(transcript.text.text == "" or transcript.text.text == nil, "test_initial_layout_called: transcript.text should be set to empty string")
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
