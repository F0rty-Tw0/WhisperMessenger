local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule

local ScrollView = loadModule("WhisperMessenger.UI.ScrollView", "ScrollView")

-- Load StatusLine module (registers on ns as side effect)
local _ = ns.ConversationPaneStatusLine or require("WhisperMessenger.UI.ConversationPane.StatusLine") -- luacheck: ignore 211
local TranscriptView = ns.ConversationPaneTranscriptView
  or require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local HeaderView = ns.ConversationPaneHeaderView or require("WhisperMessenger.UI.ConversationPane.HeaderView")

local sizeValue = TranscriptView._sizeValue
local pointValue = TranscriptView._pointValue

local ConversationPane = {}

local TRANSCRIPT_SCROLL_STEP = TranscriptView.TRANSCRIPT_SCROLL_STEP
local TRANSCRIPT_BOTTOM_GAP = TranscriptView.TRANSCRIPT_BOTTOM_GAP
local MESSAGES_PAGE_SIZE = TranscriptView.MESSAGES_PAGE_SIZE

-- Re-export transcript helpers
ConversationPane.RenderTranscript = TranscriptView.RenderTranscript
ConversationPane.HasMore = TranscriptView.HasMore
ConversationPane.LoadMore = TranscriptView.LoadMore

-- Re-export header refresh
ConversationPane.Refresh = function(view, selectedContact, conversation, status)
  HeaderView.Refresh(view, selectedContact, conversation, status)
  -- Reset visible count when conversation changes
  view.transcript._visibleCount = MESSAGES_PAGE_SIZE
  ConversationPane.RenderTranscript(view.transcript, conversation and conversation.messages or {})
  ConversationPane.SetStatus(view, status)
  return view
end

function ConversationPane.SetStatus(view, status)
  if view.statusBanner == nil then
    return nil
  end

  view.statusBanner:SetText(status and status.status or "")
  return view.statusBanner.text
end

function ConversationPane.Create(factory, parent, selectedContact, conversation)
  local pane = factory.CreateFrame("Frame", nil, parent)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 600)
  local parentHeight = sizeValue(parent, "GetHeight", "height", 420)
  pane:SetAllPoints(parent)

  local HEADER_HEIGHT = 56

  ---------------------------------------------------------------------------
  -- Header
  ---------------------------------------------------------------------------
  local header = HeaderView.Create(factory, pane, selectedContact, { HEADER_HEIGHT = HEADER_HEIGHT })
  local headerFrame = header.headerFrame

  ---------------------------------------------------------------------------
  -- Legacy statusBanner (kept for SetStatus compatibility)
  ---------------------------------------------------------------------------
  local statusBanner = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusBanner:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
  statusBanner:SetText("")

  ---------------------------------------------------------------------------
  -- Transcript ScrollView (anchored below header)
  ---------------------------------------------------------------------------
  local transcriptHeight = parentHeight - HEADER_HEIGHT - TRANSCRIPT_BOTTOM_GAP
  local transcript = ScrollView.Create(factory, pane, {
    width = parentWidth - 32,
    height = transcriptHeight,
    point = { "TOPLEFT", headerFrame, "BOTTOMLEFT", 16, -8 },
    step = TRANSCRIPT_SCROLL_STEP,
  })
  transcript.factory = factory
  transcript.point = pointValue(transcript.scrollFrame, nil)
  transcript.width = sizeValue(transcript.scrollFrame, "GetWidth", "width", parentWidth - 32)
  transcript.height = sizeValue(transcript.scrollFrame, "GetHeight", "height", transcriptHeight)
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
  TranscriptView._updateTranscriptLayout(transcript, false)

  -- Infinite scroll: load older messages when scrolling near the top
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

  local view = {
    frame = pane,
    -- Legacy header stub so any callers using view.header:SetText() don't crash
    header = header.headerName,
    headerFrame = header.headerFrame,
    headerClassIcon = header.headerClassIcon,
    headerName = header.headerName,
    headerFactionIcon = header.headerFactionIcon,
    headerStatus = header.headerStatus,
    headerStatusDot = header.headerStatusDot,
    headerEmpty = header.headerEmpty,
    statusBanner = statusBanner,
    transcript = transcript,
  }

  ConversationPane.Refresh(view, selectedContact, conversation)
  return view
end

ns.ConversationPane = ConversationPane

return ConversationPane
