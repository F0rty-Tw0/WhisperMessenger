local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")

local StatusLine = ns.ConversationPaneStatusLine or require("WhisperMessenger.UI.ConversationPane.StatusLine")
local TranscriptView = ns.ConversationPaneTranscriptView or require("WhisperMessenger.UI.ConversationPane.TranscriptView")
local HeaderView = ns.ConversationPaneHeaderView or require("WhisperMessenger.UI.ConversationPane.HeaderView")
local HeaderElements = ns.ConversationPaneHeaderElements or require("WhisperMessenger.UI.ConversationPane.HeaderElements")
local TranscriptSetup = ns.ConversationPaneTranscriptSetup or require("WhisperMessenger.UI.ConversationPane.TranscriptSetup")
local EdgeFade = ns.ConversationPaneEdgeFade or require("WhisperMessenger.UI.ConversationPane.EdgeFade")
local ChannelContextMerger = ns.ConversationPaneChannelContextMerger or require("WhisperMessenger.UI.ConversationPane.ChannelContextMerger")

local sizeValue = TranscriptView._sizeValue
local pointValue = TranscriptView._pointValue

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyColor = UIHelpers.applyColor
local ConversationPane = {}

local TRANSCRIPT_SCROLL_STEP = TranscriptView.TRANSCRIPT_SCROLL_STEP
local ACTIVE_STATUS_BANNER_HEIGHT = 24

-- Shared, never mutated: viewport-size and theme changes must re-lay-out the
-- bubbles even though no individual message changed.
local FORCE_RENDER = { force = true }

ConversationPane.RenderTranscript = TranscriptView.RenderTranscript

local function buildMessagesWithChannelContext(messages, selectedContact, conversation)
  return ChannelContextMerger.Merge(messages, selectedContact, {
    channelMessageStore = ns.ChannelMessageStore,
    channelMessageState = ns._channelMessageState,
    conversation = conversation,
    now = type(_G["time"]) == "function" and _G["time"]() or nil,
  })
end

local function transcriptIsAtEnd(transcript)
  local range = ScrollView.GetRange(transcript)
  return range <= 0 or ScrollView.GetOffset(transcript) >= range - 1
end

ConversationPane.Refresh = function(view, selectedContact, conversation, status, noticeText)
  local selectedConversationKey = selectedContact and selectedContact.conversationKey or nil
  if view._selectedConversationKey ~= selectedConversationKey then
    TranscriptView.Reset(view.transcript)
  end
  view._selectedConversationKey = selectedConversationKey
  view._selectedContact = selectedContact
  view._conversation = conversation
  view._status = status
  HeaderView.Refresh(view, selectedContact, conversation, status)
  -- Pass classTag from selected contact so chat bubbles can use it as fallback
  -- when individual messages lack classTag (e.g., older BNet messages)
  view.transcript.fallbackClassTag = selectedContact and selectedContact.classTag or nil
  local messages = conversation and conversation.messages or {}
  messages = buildMessagesWithChannelContext(messages, selectedContact, conversation)
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
    local wasAtEnd = transcriptIsAtEnd(t)
    local delta = view._activeStatusVisible and -ACTIVE_STATUS_BANNER_HEIGHT or ACTIVE_STATUS_BANNER_HEIGHT
    local currentH = sizeValue(t.scrollFrame, "GetHeight", "height", 0)
    if currentH > 0 then
      local newH = currentH + delta
      t.scrollFrame:SetSize(sizeValue(t.scrollFrame, "GetWidth", "width", 0), newH)
      t.scrollBar:SetHeight(newH)
      t.viewportHeight = newH
      if t._allMessages then
        t._virtualForceEnd = wasAtEnd
        TranscriptView.RenderTranscript(t, t._allMessages, FORCE_RENDER)
      else
        ScrollView.RefreshMetrics(t, sizeValue(t.content, "GetHeight", "height", 0), false)
      end
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

function ConversationPane.SetLanguage(view)
  if view == nil then
    return
  end
  HeaderView.SetLanguage(view)
  -- Re-running Refresh re-resolves the localized status line (StatusLine.Build
  -- routes availability/class/faction labels through Localization on each call)
  -- so the header reflects the new language without waiting for the next
  -- selection change.
  if view._selectedContact ~= nil or view._conversation ~= nil then
    HeaderView.Refresh(view, view._selectedContact, view._conversation, view._status)
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

function ConversationPane.Create(factory, parent, selectedContact, conversation, options)
  options = options or {}
  local pane = factory.CreateFrame("Frame", nil, parent)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 600)
  local parentHeight = sizeValue(parent, "GetHeight", "height", 420)
  pane:SetAllPoints(parent)

  -- Header

  local header = HeaderView.Create(factory, pane, selectedContact, {
    HEADER_HEIGHT = Theme.LAYOUT.HEADER_HEIGHT,
    nativeChrome = options.hideEmptyHeader == true,
  })
  local headerFrame = header.headerFrame

  -- Legacy statusBanner (hidden; status is shown in header status line)

  local statusBanner = pane:CreateFontString(nil, "OVERLAY", Theme.FONTS.system_text)
  statusBanner:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", 0, 0)
  statusBanner:SetText("")
  statusBanner:Hide()

  -- Transcript ScrollView (anchored below header)

  -- Flush with the header divider and the composer line; the transcript
  -- pads its own content.
  local transcriptHeight = parentHeight - Theme.LAYOUT.HEADER_HEIGHT
  local transcript = ScrollView.Create(factory, pane, {
    width = parentWidth - Theme.LAYOUT.TRANSCRIPT_HORIZONTAL_INSET,
    height = transcriptHeight,
    point = { "TOPLEFT", headerFrame, "BOTTOMLEFT", Theme.LAYOUT.TRANSCRIPT_LEFT_GUTTER, 0 },
    step = TRANSCRIPT_SCROLL_STEP,
  })
  transcript.factory = factory
  transcript.point = pointValue(transcript.scrollFrame, nil)
  transcript.width = sizeValue(transcript.scrollFrame, "GetWidth", "width", parentWidth - Theme.LAYOUT.TRANSCRIPT_HORIZONTAL_INSET)
  transcript.height = sizeValue(transcript.scrollFrame, "GetHeight", "height", transcriptHeight)
  TranscriptSetup.ConfigureTranscript(factory, transcript, parentWidth)

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
    headerStatusDetail = header.headerStatusDetail,
    headerAddonBadge = header.headerAddonBadge,
    headerAddonBadgeButton = header.headerAddonBadgeButton,
    headerStatusDot = header.headerStatusDot,
    headerDivider = header.headerDivider,
    headerEmpty = header.headerEmpty,
    headerChannelChip = header.headerChannelChip,
    statusBanner = statusBanner,
    activeStatusBanner = activeStatusBanner,
    transcript = transcript,
    -- Native WoW HUD sits on Blizzard art a flat-colour fade would not match.
    edgeFade = EdgeFade.Attach(factory, pane, transcript),
    refreshTheme = function()
      if view.headerFrame and view.headerFrame.bg then
        UIHelpers.applyColorTexture(view.headerFrame.bg, Theme.COLORS.bg_header)
      end
      if view.headerDivider then
        HeaderElements.applyDividerTheme(view.headerDivider)
      end
      HeaderView.Refresh(view, view._selectedContact, view._conversation, view._status)
      if view.headerStatus then
        applyColor(view.headerStatus, Theme.COLORS.text_secondary)
      end
      if view.headerStatusDetail then
        applyColor(view.headerStatusDetail, Theme.COLORS.text_secondary)
      end
      if view.headerEmpty and view.headerEmpty.applyTheme then
        view.headerEmpty.applyTheme()
      end
      if view.activeStatusBanner then
        applyColor(view.activeStatusBanner, Theme.COLORS.text_system)
      end
      if view.edgeFade then
        view.edgeFade.refreshTheme()
      end
      if view.transcript and view.transcript.refreshSkin then
        view.transcript.refreshSkin()
      end
      if view.transcript and view.transcript._allMessages then
        TranscriptView.RenderTranscript(view.transcript, view.transcript._allMessages, FORCE_RENDER)
      end
    end,
  }

  HeaderView.Relayout(view, parentWidth)

  if type(options.onReact) == "function" then
    transcript.onReact = function(message, reactionKey)
      return options.onReact(view._selectedContact, message, reactionKey)
    end
  end

  if type(options.canReact) == "function" then
    transcript.canReact = function(message)
      return options.canReact(view._selectedContact, message)
    end
  end

  -- Read by the header's addon badge button when the invite hint is clicked.
  if type(options.onInviteContact) == "function" then
    view.onInviteContact = options.onInviteContact
  end

  view.hideEmptyHeader = options.hideEmptyHeader == true
  ConversationPane.Refresh(view, selectedContact, conversation)
  return view
end

-- Resize the transcript scroll view to match new thread pane dimensions.
-- width, height: new threadPane dimensions
function ConversationPane.Relayout(view, width, height)
  if view == nil then
    return
  end

  HeaderView.Relayout(view, width)
  if view.transcript == nil then
    return
  end
  local bannerOffset = view._activeStatusVisible and ACTIVE_STATUS_BANNER_HEIGHT or 0
  -- The pane is dual-anchored in the live client, so its real height can
  -- differ from the window-derived metric; size the transcript to what the
  -- pane actually is so bubbles reach the composer instead of stopping short.
  local paneHeight = sizeValue(view.frame, "GetHeight", "height", height)
  local transcriptW = width - Theme.LAYOUT.TRANSCRIPT_HORIZONTAL_INSET
  local transcriptH = paneHeight - Theme.LAYOUT.HEADER_HEIGHT - bannerOffset
  local t = view.transcript
  local wasAtEnd = transcriptIsAtEnd(t)
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
    t._virtualForceEnd = wasAtEnd
    TranscriptView.RenderTranscript(t, t._allMessages, FORCE_RENDER)
  end
end

ns.ConversationPane = ConversationPane

return ConversationPane
