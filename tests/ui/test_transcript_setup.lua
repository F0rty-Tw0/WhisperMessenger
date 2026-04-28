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

  -- test_configure_creates_edit_box

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    assert(transcript.text ~= nil, "test_configure_creates_edit_box: transcript.text should be created")
  end

  -- test_edit_box_is_multiline

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    assert(transcript.text.multiline == true, "test_edit_box_is_multiline: SetMultiLine(true) should be called")
  end

  -- test_edit_box_auto_focus_disabled

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    assert(transcript.text.autoFocus == false, "test_edit_box_auto_focus_disabled: SetAutoFocus(false) should be called")
  end

  -- test_edit_box_hyperlinks_enabled

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    assert(transcript.text.hyperlinksEnabled == true, "test_edit_box_hyperlinks_enabled: SetHyperlinksEnabled(true) should be called")
  end

  -- test_url_hyperlink_click_avoids_protected_launch_and_copies_link

  do
    local savedExternalEventURL = _G.C_ExternalEventURL
    local savedLaunchURL = _G.LaunchURL
    local savedClipboardNamespace = _G.C_Clipboard

    local launchAttempted = false
    local copiedUrl = nil

    _G.C_ExternalEventURL = {
      LaunchURL = function()
        launchAttempted = true
      end,
    }
    _G.LaunchURL = function()
      launchAttempted = true
    end
    _G.C_Clipboard = {
      SetClipboard = function(text)
        copiedUrl = text
      end,
    }

    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)
    transcript.text.scripts.OnHyperlinkClick(transcript.text, "url:https://example.com/help", "https://example.com/help", "LeftButton")

    assert(launchAttempted == false, "expected transcript URL click to avoid protected LaunchURL APIs")
    assert(copiedUrl == "https://example.com/help", "expected transcript URL click to copy URL as safe fallback")

    _G.C_ExternalEventURL = savedExternalEventURL
    _G.LaunchURL = savedLaunchURL
    _G.C_Clipboard = savedClipboardNamespace
  end

  -- test_initial_layout_called

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local stub = makeConversationPaneStub()

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    -- After ConfigureTranscript, transcript.text should exist and have empty text
    assert(transcript.text ~= nil, "test_initial_layout_called: transcript.text must exist after configure")
    assert(transcript.text.text == "" or transcript.text.text == nil, "test_initial_layout_called: transcript.text should be set to empty string")
  end

  -- test_scroll_wiring_preserves_original_mouse_wheel_handler

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local heights = { 600, 720, 840, 960, 1080 }
    local loadMoreCalls = 0
    local wheelOriginalCalled = false
    local wheelDelta = nil
    local stub = {
      HasMore = function(_transcript)
        return loadMoreCalls < 4
      end,
      LoadMore = function(target)
        loadMoreCalls = loadMoreCalls + 1
        target.content:SetSize(target.content:GetWidth(), heights[loadMoreCalls + 1])
      end,
    }

    transcript.scrollFrame:SetScript("OnMouseWheel", function(_self, delta)
      wheelOriginalCalled = true
      wheelDelta = delta
    end)

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    transcript.content:SetSize(transcript.content:GetWidth(), heights[1])
    transcript.scrollFrame.verticalScroll = TranscriptView.TRANSCRIPT_SCROLL_STEP

    local wheelHandler = transcript.scrollFrame:GetScript("OnMouseWheel")
    assert(type(wheelHandler) == "function", "test_scroll_wiring_preserves_original_mouse_wheel_handler: OnMouseWheel handler must exist")
    wheelHandler(transcript.scrollFrame, -1)
    assert(wheelOriginalCalled, "test_scroll_wiring_preserves_original_mouse_wheel_handler: original OnMouseWheel handler should be called")
    assert(
      wheelDelta == -1,
      "test_scroll_wiring_preserves_original_mouse_wheel_handler: original OnMouseWheel handler should receive the wheel delta"
    )
    assert(
      loadMoreCalls > 0,
      "test_scroll_wiring_preserves_original_mouse_wheel_handler: OnMouseWheel should still trigger transcript loading near the top"
    )
    assert(
      transcript.content:GetHeight() > heights[1],
      "test_scroll_wiring_preserves_original_mouse_wheel_handler: OnMouseWheel should still grow the transcript content when loading older messages"
    )
  end

  -- test_scroll_wiring_preserves_original_value_changed_handler

  do
    local factory = FakeUI.NewFactory()
    local transcript = makeTranscript(factory)
    local heights = { 600, 720, 840, 960, 1080 }
    local loadMoreCalls = 0
    local valueOriginalCalled
    local valueSeen
    local stub = {
      HasMore = function(_transcript)
        return loadMoreCalls < 4
      end,
      LoadMore = function(target)
        loadMoreCalls = loadMoreCalls + 1
        target.content:SetSize(target.content:GetWidth(), heights[loadMoreCalls + 1])
      end,
    }

    transcript.scrollBar:SetScript("OnValueChanged", function(_self, value)
      valueOriginalCalled = true
      if valueSeen == nil then
        valueSeen = value
      end
    end)

    TranscriptSetup.ConfigureTranscript(factory, transcript, 600, stub)

    transcript.content:SetSize(transcript.content:GetWidth(), heights[1])
    transcript.scrollFrame.verticalScroll = TranscriptView.TRANSCRIPT_SCROLL_STEP

    local valueHandler = transcript.scrollBar:GetScript("OnValueChanged")
    assert(type(valueHandler) == "function", "test_scroll_wiring_preserves_original_value_changed_handler: OnValueChanged handler must exist")
    valueOriginalCalled = false
    valueSeen = nil
    valueHandler(transcript.scrollBar, TranscriptView.TRANSCRIPT_SCROLL_STEP)
    assert(valueOriginalCalled, "test_scroll_wiring_preserves_original_value_changed_handler: original OnValueChanged handler should be called")
    assert(
      valueSeen == TranscriptView.TRANSCRIPT_SCROLL_STEP,
      "test_scroll_wiring_preserves_original_value_changed_handler: original OnValueChanged handler should receive the scroll value"
    )
    assert(
      loadMoreCalls > 0,
      "test_scroll_wiring_preserves_original_value_changed_handler: OnValueChanged should still trigger transcript loading near the top"
    )
    assert(
      transcript.content:GetHeight() > heights[1],
      "test_scroll_wiring_preserves_original_value_changed_handler: OnValueChanged should still grow the transcript content when loading older messages"
    )
  end
end
