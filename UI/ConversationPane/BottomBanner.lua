local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local TranscriptView = ns.ConversationPaneTranscriptView or require("WhisperMessenger.UI.ConversationPane.TranscriptView")

local sizeValue = TranscriptView._sizeValue

-- The strip above the composer: the message-request banner wins, else the
-- messaging notice, else the "Replying to" strip, else the contact's AFK/DND
-- text. The transcript shrinks by HEIGHT while any of them shows, or by the
-- notice's wrapped text height when a long notice needs more lines.
local BottomBanner = {}

BottomBanner.HEIGHT = 24
-- Gap below the notice text (its bottom anchor offset) and above it.
local TEXT_INSET = 4

-- Space the transcript gives up for the strip: 0 when nothing shows.
function BottomBanner.ReservedHeight(view)
  if not view._activeStatusVisible then
    return 0
  end
  if view._isRequest == true then
    return math.max(BottomBanner.HEIGHT, view.requestBanner.layout())
  end
  local banner = view.activeStatusBanner
  if not banner:IsShown() then
    return BottomBanner.HEIGHT
  end
  local textHeight = math.ceil(banner:GetStringHeight() or 0)
  return math.max(BottomBanner.HEIGHT, textHeight + 2 * TEXT_INSET)
end

local function resizeTranscript(view, delta)
  local t = view.transcript
  if t == nil then
    return
  end
  local wasAtEnd = TranscriptView.IsAtEnd(t)
  local currentH = sizeValue(t.scrollFrame, "GetHeight", "height", 0)
  if currentH <= 0 then
    return
  end
  local newH = currentH + delta
  t.scrollFrame:SetSize(sizeValue(t.scrollFrame, "GetWidth", "width", 0), newH)
  t.scrollBar:SetHeight(newH)
  t.viewportHeight = newH
  if t._allMessages then
    t._virtualForceEnd = wasAtEnd
    -- A height change must re-lay-out the bubbles.
    TranscriptView.RenderTranscript(t, t._allMessages, TranscriptView.FORCE_RENDER)
  else
    ScrollView.RefreshMetrics(t, sizeValue(t.content, "GetHeight", "height", 0), false)
  end
end

function BottomBanner.Refresh(view)
  if view.activeStatusBanner == nil then
    return
  end

  local noticeText = view._noticeText or ""
  local showRequest = view._isRequest == true
  local showReply = view._replyTo ~= nil and not showRequest and noticeText == ""
  local nextText = noticeText
  if nextText == "" and not showReply and view._activeStatusText and view._activeStatusText ~= "" then
    nextText = view._activeStatusText
  end
  view.requestBanner.setShown(showRequest)
  view.replyBanner.setShown(showReply)

  if showRequest or showReply then
    view.activeStatusBanner:Hide()
    view._activeStatusVisible = true
  elseif nextText ~= "" then
    view.activeStatusBanner:SetText(nextText)
    view.activeStatusBanner:Show()
    view._activeStatusVisible = true
  else
    view.activeStatusBanner:SetText("")
    view.activeStatusBanner:Hide()
    view._activeStatusVisible = false
  end

  local previous = view._bannerReserved or 0
  local reserved = BottomBanner.ReservedHeight(view)
  view._bannerReserved = reserved
  if reserved ~= previous then
    resizeTranscript(view, previous - reserved)
  end
end

ns.ConversationPaneBottomBanner = BottomBanner
return BottomBanner
