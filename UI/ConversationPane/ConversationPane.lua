local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")

local StatusLine = ns.ConversationPaneStatusLine or require("WhisperMessenger.UI.ConversationPane.StatusLine")
local TranscriptView = ns.ConversationPaneTranscriptView
  or require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local HeaderView = ns.ConversationPaneHeaderView or require("WhisperMessenger.UI.ConversationPane.HeaderView")

local sizeValue = TranscriptView._sizeValue
local pointValue = TranscriptView._pointValue

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColor = UIHelpers.applyColor
local applyColorTexture = UIHelpers.applyColorTexture

local ConversationPane = {}

local TRANSCRIPT_SCROLL_STEP = TranscriptView.TRANSCRIPT_SCROLL_STEP
local TRANSCRIPT_BOTTOM_GAP = TranscriptView.TRANSCRIPT_BOTTOM_GAP
local MESSAGES_PAGE_SIZE = TranscriptView.MESSAGES_PAGE_SIZE
local ACTIVE_STATUS_BANNER_HEIGHT = 24

-- Re-export transcript helpers
ConversationPane.RenderTranscript = TranscriptView.RenderTranscript
ConversationPane.HasMore = TranscriptView.HasMore
ConversationPane.LoadMore = TranscriptView.LoadMore

-- Re-export header refresh
ConversationPane.Refresh = function(view, selectedContact, conversation, status)
  HeaderView.Refresh(view, selectedContact, conversation, status)
  -- Reset visible count when conversation changes
  view.transcript._visibleCount = MESSAGES_PAGE_SIZE
  -- Pass classTag from selected contact so chat bubbles can use it as fallback
  -- when individual messages lack classTag (e.g., older BNet messages)
  view.transcript.fallbackClassTag = selectedContact and selectedContact.classTag or nil
  ConversationPane.RenderTranscript(view.transcript, conversation and conversation.messages or {})
  ConversationPane.SetStatus(view, status)
  ConversationPane.RefreshActiveStatus(view, conversation and conversation.activeStatus or nil)
  return view
end

function ConversationPane.RefreshActiveStatus(view, activeStatus)
  if view.activeStatusBanner == nil then
    return
  end

  local wasVisible = view._activeStatusVisible or false

  if activeStatus and activeStatus.text and activeStatus.text ~= "" then
    view.activeStatusBanner:SetText(activeStatus.text)
    view.activeStatusBanner:Show()
    view._activeStatusVisible = true
  else
    view.activeStatusBanner:SetText("")
    view.activeStatusBanner:Hide()
    view._activeStatusVisible = false
  end

  -- Adjust transcript height when banner visibility changes
  if view._activeStatusVisible ~= wasVisible and view.transcript then
    local t = view.transcript
    local delta = view._activeStatusVisible and -ACTIVE_STATUS_BANNER_HEIGHT or ACTIVE_STATUS_BANNER_HEIGHT
    local currentH = sizeValue(t.scrollFrame, "GetHeight", "height", 0)
    if currentH > 0 then
      local newH = currentH + delta
      t.scrollFrame:SetSize(sizeValue(t.scrollFrame, "GetWidth", "width", 0), newH)
      t.scrollBar:SetHeight(newH)
      t.viewportHeight = newH
      ScrollView.RefreshMetrics(t, sizeValue(t.content, "GetHeight", "height", 0), true)
    end
  end
end

function ConversationPane.SetStatus(view, status)
  if view.statusBanner == nil then
    return nil
  end

  local label = ""
  if status and status.status and StatusLine and StatusLine.AVAILABILITY_DISPLAY then
    local avail = StatusLine.AVAILABILITY_DISPLAY[status.status]
    if avail then
      label = avail.label
    end
  end
  view.statusBanner:SetText(label)
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
  -- Legacy statusBanner (hidden; status is shown in header status line)
  ---------------------------------------------------------------------------
  local statusBanner = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusBanner:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
  statusBanner:SetText("")
  statusBanner:Hide()

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

  ---------------------------------------------------------------------------
  -- Active status banner (above composer, shown for AFK/DND)
  ---------------------------------------------------------------------------
  local activeStatusBanner = pane:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  activeStatusBanner:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 16, 4)
  activeStatusBanner:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -16, 4)
  activeStatusBanner:SetText("")
  applyColor(activeStatusBanner, Theme.COLORS.text_system)
  activeStatusBanner:Hide()

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
    activeStatusBanner = activeStatusBanner,
    transcript = transcript,
  }

  ConversationPane.Refresh(view, selectedContact, conversation)
  return view
end

-- Resize the transcript scroll view to match new thread pane dimensions.
-- width, height: new threadPane dimensions
function ConversationPane.Relayout(view, width, height)
  if view == nil or view.transcript == nil then
    return
  end
  local HEADER_HEIGHT = 56
  local bannerOffset = view._activeStatusVisible and ACTIVE_STATUS_BANNER_HEIGHT or 0
  local transcriptW = width - 32
  local transcriptH = height - HEADER_HEIGHT - TRANSCRIPT_BOTTOM_GAP - bannerOffset
  local t = view.transcript
  t.scrollFrame:SetSize(transcriptW, transcriptH)
  t.content:SetSize(transcriptW, t.content.height or transcriptH)
  t.scrollBar:SetHeight(transcriptH)
  t.viewportHeight = transcriptH
  t.totalWidth = transcriptW
  if t.text and t.text.SetWidth then
    t.text:SetWidth(transcriptW)
  end
  -- Re-render bubbles at the new width
  if t._allMessages then
    TranscriptView.RenderTranscript(t, t._allMessages)
  end
end

ns.ConversationPane = ConversationPane

return ConversationPane
