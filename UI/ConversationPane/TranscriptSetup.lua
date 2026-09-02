local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Navigation = ns.ScrollViewNavigation or require("WhisperMessenger.UI.ScrollView.Navigation")
local TranscriptView = ns.ConversationPaneTranscriptView or require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Hyperlinks = ns.UIHyperlinks or require("WhisperMessenger.UI.Hyperlinks")
local sizeValue = UIHelpers.sizeValue

local TranscriptSetup = {}

function TranscriptSetup.ConfigureTranscript(factory, transcript, parentWidth)
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

  TranscriptView._updateTranscriptLayout(transcript, false)

  local function refreshViewport()
    TranscriptView.RefreshViewport(transcript)
  end

  Navigation.InstallPostScrollHook(transcript, refreshViewport)
end

ns.ConversationPaneTranscriptSetup = TranscriptSetup

return TranscriptSetup
