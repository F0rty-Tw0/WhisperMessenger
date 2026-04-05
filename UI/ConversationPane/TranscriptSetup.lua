local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local Navigation = ns.ScrollViewNavigation or require("WhisperMessenger.UI.ScrollView.Navigation")
local TranscriptView = ns.ConversationPaneTranscriptView
  or require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Hyperlinks = ns.UIHyperlinks or require("WhisperMessenger.UI.Hyperlinks")
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
    transcript.text:SetFontObject(_G[Theme.FONTS.system_text] or Theme.FONTS.system_text)
  end
  if transcript.text.SetWidth then
    transcript.text:SetWidth(sizeValue(transcript.scrollFrame, "GetWidth", "width", parentWidth - 32))
  end
  if transcript.text.SetScript then
    transcript.text:SetScript("OnHyperlinkClick", function(self, link, text, button)
      Hyperlinks.HandleClick(link, text, button, self)
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

  Navigation.InstallPostScrollHook(transcript, checkLoadMoreMessages)
end

ns.ConversationPaneTranscriptSetup = TranscriptSetup

return TranscriptSetup
