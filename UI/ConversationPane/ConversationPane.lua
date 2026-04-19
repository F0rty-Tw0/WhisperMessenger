local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")

local StatusLine = ns.ConversationPaneStatusLine or require("WhisperMessenger.UI.ConversationPane.StatusLine")
local TranscriptView = ns.ConversationPaneTranscriptView
  or require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local HeaderView = ns.ConversationPaneHeaderView or require("WhisperMessenger.UI.ConversationPane.HeaderView")
local TranscriptSetup = ns.ConversationPaneTranscriptSetup
  or require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")

local sizeValue = TranscriptView._sizeValue
local pointValue = TranscriptView._pointValue

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Skins = ns.Skins or require("WhisperMessenger.UI.Theme.Skins")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColor = UIHelpers.applyColor
local applyColorTexture = UIHelpers.applyColorTexture
local applyPaneBackground = UIHelpers.applyPaneBackground
local ConversationPane = {}

local TRANSCRIPT_SCROLL_STEP = TranscriptView.TRANSCRIPT_SCROLL_STEP
local TRANSCRIPT_BOTTOM_GAP = TranscriptView.TRANSCRIPT_BOTTOM_GAP
local MESSAGES_PAGE_SIZE = TranscriptView.MESSAGES_PAGE_SIZE
local ACTIVE_STATUS_BANNER_HEIGHT = 24

ConversationPane.RenderTranscript = TranscriptView.RenderTranscript
ConversationPane.HasMore = TranscriptView.HasMore
ConversationPane.LoadMore = TranscriptView.LoadMore

-- Build a messages list that includes any recent channel context message
-- for the selected contact, inserted at its chronological position.
local function buildMessagesWithChannelContext(messages, selectedContact)
  local ChannelMessageStore = ns.ChannelMessageStore
  if not ChannelMessageStore or not selectedContact then
    return messages
  end
  local storeState = ns._channelMessageState
  if not storeState then
    return messages
  end
  -- Derive lookup name: prefer gameAccountName (BNet in-game char), then displayName
  local lookupName = selectedContact.gameAccountName or selectedContact.displayName
  if not lookupName or lookupName == "" then
    return messages
  end
  lookupName = string.lower(lookupName)
  local now = type(_G["time"]) == "function" and _G["time"]() or nil
  local entry = ChannelMessageStore.GetLatest(storeState, lookupName, now)
  if not entry then
    return messages
  end

  local channelMsg = {
    id = "channel-ctx-" .. tostring(entry.sentAt),
    direction = "in",
    kind = "channel_context",
    text = entry.text,
    sentAt = entry.sentAt,
    playerName = selectedContact.displayName or entry.playerName,
    channelLabel = entry.channelLabel,
  }

  -- Insert at correct chronological position
  local result = {}
  local inserted = false
  for _, m in ipairs(messages) do
    if not inserted and (channelMsg.sentAt or 0) < (m.sentAt or 0) then
      result[#result + 1] = channelMsg
      inserted = true
    end
    result[#result + 1] = m
  end
  if not inserted then
    result[#result + 1] = channelMsg
  end
  return result
end

ConversationPane.Refresh = function(view, selectedContact, conversation, status, noticeText)
  view._selectedContact = selectedContact
  view._conversation = conversation
  view._status = status
  HeaderView.Refresh(view, selectedContact, conversation, status)
  -- Reset visible count when conversation changes
  view.transcript._visibleCount = MESSAGES_PAGE_SIZE
  -- Pass classTag from selected contact so chat bubbles can use it as fallback
  -- when individual messages lack classTag (e.g., older BNet messages)
  view.transcript.fallbackClassTag = selectedContact and selectedContact.classTag or nil
  local messages = conversation and conversation.messages or {}
  messages = buildMessagesWithChannelContext(messages, selectedContact)
  ConversationPane.RenderTranscript(view.transcript, messages)
  ConversationPane.SetStatus(view, status)
  ConversationPane.SetNotice(view, noticeText)
  ConversationPane.RefreshActiveStatus(view, conversation and conversation.activeStatus or nil)
  return view
end

local function refreshBottomBanner(view)
  if view.activeStatusBanner == nil then
    return
  end

  local wasVisible = view._activeStatusVisible or false
  local nextText = view._noticeText or ""
  if nextText == "" and view._activeStatusText and view._activeStatusText ~= "" then
    nextText = view._activeStatusText
  end

  if nextText ~= "" then
    view.activeStatusBanner:SetText(nextText)
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

function ConversationPane.SetNotice(view, noticeText)
  view._noticeText = noticeText or ""
  refreshBottomBanner(view)
end

function ConversationPane.RefreshActiveStatus(view, activeStatus)
  view._activeStatusText = activeStatus and activeStatus.text or ""
  refreshBottomBanner(view)
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

  -- Header

  local header = HeaderView.Create(factory, pane, selectedContact, { HEADER_HEIGHT = Theme.LAYOUT.HEADER_HEIGHT })
  local headerFrame = header.headerFrame

  -- Legacy statusBanner (hidden; status is shown in header status line)

  local statusBanner = pane:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  statusBanner:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
  statusBanner:SetText("")
  statusBanner:Hide()

  -- Transcript ScrollView (anchored below header)

  local transcriptHeight = parentHeight - Theme.LAYOUT.HEADER_HEIGHT - TRANSCRIPT_BOTTOM_GAP
  local transcript = ScrollView.Create(factory, pane, {
    width = parentWidth - Theme.LAYOUT.TRANSCRIPT_HORIZONTAL_INSET,
    height = transcriptHeight,
    point = { "TOPLEFT", headerFrame, "BOTTOMLEFT", Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER, -8 },
    step = TRANSCRIPT_SCROLL_STEP,
  })
  transcript.factory = factory
  transcript.point = pointValue(transcript.scrollFrame, nil)
  transcript.width =
    sizeValue(transcript.scrollFrame, "GetWidth", "width", parentWidth - Theme.LAYOUT.TRANSCRIPT_HORIZONTAL_INSET)
  transcript.height = sizeValue(transcript.scrollFrame, "GetHeight", "height", transcriptHeight)
  TranscriptSetup.ConfigureTranscript(factory, transcript, parentWidth, ConversationPane)

  -- Active status banner (above composer, shown for AFK/DND)

  local activeStatusBanner = pane:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  activeStatusBanner:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER, 4)
  activeStatusBanner:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER, 4)
  activeStatusBanner:SetText("")
  applyColor(activeStatusBanner, Theme.COLORS.text_system)
  activeStatusBanner:Hide()

  local view
  view = {
    frame = pane,
    -- Legacy header stub so any callers using view.header:SetText() don't crash
    header = header.headerName,
    headerFrame = header.headerFrame,
    headerClassIcon = header.headerClassIcon,
    headerName = header.headerName,
    headerFactionIcon = header.headerFactionIcon,
    headerStatus = header.headerStatus,
    headerStatusDot = header.headerStatusDot,
    headerDivider = header.headerDivider,
    headerEmpty = header.headerEmpty,
    headerChannelChip = header.headerChannelChip,
    statusBanner = statusBanner,
    activeStatusBanner = activeStatusBanner,
    transcript = transcript,
    refreshTheme = function()
      if view.headerFrame and view.headerFrame.bg then
        local skinSpec = Skins.Get(Skins.GetActive())
        applyPaneBackground(view.headerFrame.bg, Theme.COLORS.bg_header, skinSpec and skinSpec.pane_header_texture)
      end
      if view.headerDivider then
        local dividerColor = Theme.COLORS.divider or { 0.15, 0.16, 0.22, 0.60 }
        local strongColor = { dividerColor[1], dividerColor[2], dividerColor[3], 1 }
        local border = view.headerDivider._headerBorder
        if border then
          for _, edge in pairs(border) do
            applyColorTexture(edge, strongColor)
          end
        else
          applyColorTexture(view.headerDivider, strongColor)
        end
      end
      HeaderView.Refresh(view, view._selectedContact, view._conversation, view._status)
      if view.headerStatus then
        applyColor(view.headerStatus, Theme.COLORS.text_secondary)
      end
      if view.headerEmpty then
        local emptyLabel = view.headerEmpty._label or view.headerEmpty
        applyColor(emptyLabel, Theme.COLORS.text_secondary)
      end
      if view.activeStatusBanner then
        applyColor(view.activeStatusBanner, Theme.COLORS.text_system)
      end
      if view.transcript and view.transcript.refreshSkin then
        view.transcript.refreshSkin()
      end
      if view.transcript and view.transcript._allMessages then
        TranscriptView.RenderTranscript(view.transcript, view.transcript._allMessages)
      end
    end,
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
  local bannerOffset = view._activeStatusVisible and ACTIVE_STATUS_BANNER_HEIGHT or 0
  local transcriptW = width - Theme.LAYOUT.TRANSCRIPT_HORIZONTAL_INSET
  local transcriptH = height - Theme.LAYOUT.HEADER_HEIGHT - TRANSCRIPT_BOTTOM_GAP - bannerOffset
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
