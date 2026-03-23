local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local TranscriptView = ns.ConversationPaneTranscriptView
  or require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue

local TranscriptSetup = {}

local TRANSCRIPT_SCROLL_STEP = TranscriptView.TRANSCRIPT_SCROLL_STEP

--- Configure the EditBox and infinite-scroll wiring on a transcript ScrollView.
-- @param factory  Frame factory (WoW CreateFrame wrapper)
-- @param transcript  ScrollView table returned by ScrollView.Create
-- @param parentWidth  Width of the parent pane (number)
-- @param ConversationPane  The ConversationPane module (passed to avoid circular require)
function TranscriptSetup.ConfigureTranscript(factory, transcript, parentWidth, ConversationPane)
  ---------------------------------------------------------------------------
  -- EditBox setup
  ---------------------------------------------------------------------------
  transcript.text = factory.CreateFrame("EditBox", nil, transcript.content)
  transcript.text:SetPoint("TOPLEFT", transcript.content, "TOPLEFT", 0, 0)
  if transcript.text.SetMultiLine then
    transcript.text:SetMultiLine(true)
  end
  if transcript.text.SetAutoFocus then
    transcript.text:SetAutoFocus(false)
  end
  if transcript.text.EnableMouse then
    transcript.text:EnableMouse(true)
  end
  if transcript.text.SetHyperlinksEnabled then
    transcript.text:SetHyperlinksEnabled(true)
  end
  if transcript.text.SetFontObject then
    transcript.text:SetFontObject(_G.GameFontHighlightSmall or "GameFontHighlightSmall")
  end
  if transcript.text.SetWidth then
    transcript.text:SetWidth(sizeValue(transcript.scrollFrame, "GetWidth", "width", parentWidth - 32))
  end
  if transcript.text.SetScript then
    transcript.text:SetScript("OnHyperlinkClick", function(self, link, text, button)
      if type(_G.SetItemRef) == "function" then
        _G.SetItemRef(link, text, button, self)
      end
    end)
    transcript.text:SetScript("OnEditFocusGained", function(self)
      if self.ClearFocus then
        self:ClearFocus()
      end
    end)
  end
  transcript.text:SetText("")
  transcript.lines = {}

  ---------------------------------------------------------------------------
  -- Initial layout
  ---------------------------------------------------------------------------
  TranscriptView._updateTranscriptLayout(transcript, false)

  ---------------------------------------------------------------------------
  -- Infinite scroll wiring
  ---------------------------------------------------------------------------
  local function checkLoadMoreMessages()
    local offset = ScrollView.GetOffset(transcript)
    if offset <= TRANSCRIPT_SCROLL_STEP and ConversationPane.HasMore(transcript) then
      local prevHeight = sizeValue(transcript.content, "GetHeight", "height", 0)
      ConversationPane.LoadMore(transcript)
      local newHeight = sizeValue(transcript.content, "GetHeight", "height", 0)
      local delta = newHeight - prevHeight
      if delta > 0 then
        ScrollView.SetVerticalScroll(transcript, offset + delta)
      end
    end
  end

  if transcript.scrollFrame and transcript.scrollFrame.SetScript then
    local originalOnWheel = transcript.scrollFrame:GetScript("OnMouseWheel")
    transcript.scrollFrame:SetScript("OnMouseWheel", function(self, delta)
      if originalOnWheel then
        originalOnWheel(self, delta)
      end
      checkLoadMoreMessages()
    end)
  end

  if transcript.scrollBar and transcript.scrollBar.SetScript then
    local originalOnValue = transcript.scrollBar:GetScript("OnValueChanged")
    transcript.scrollBar:SetScript("OnValueChanged", function(self, value)
      if originalOnValue then
        originalOnValue(self, value)
      end
      checkLoadMoreMessages()
    end)
  end
end

ns.ConversationPaneTranscriptSetup = TranscriptSetup

return TranscriptSetup
