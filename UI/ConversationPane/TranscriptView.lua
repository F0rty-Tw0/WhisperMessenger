local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Virtualization = ns.ConversationPaneTranscriptVirtualization or require("WhisperMessenger.UI.ConversationPane.TranscriptVirtualization")
local MessageReplies = ns.MessageReplies or require("WhisperMessenger.Model.MessageReplies")
local TranscriptRows = ns.ConversationPaneTranscriptRows or require("WhisperMessenger.UI.ConversationPane.TranscriptRows")
local sizeValue = UIHelpers.sizeValue

local TranscriptView = {}

TranscriptView.TRANSCRIPT_SCROLL_STEP = 24
-- Render option that rebuilds every bubble (theme or font change). Shared,
-- never mutated.
TranscriptView.FORCE_RENDER = { force = true }
-- Render option for a viewport size change: a full layout pass that keeps
-- the bubbles of rows whose width did not change. Shared, never mutated.
TranscriptView.RELAYOUT_RENDER = { relayout = true }

-- True when the transcript is scrolled to (within 1px of) its end.
function TranscriptView.IsAtEnd(transcript)
  local range = ScrollView.GetRange(transcript)
  return range <= 0 or ScrollView.GetOffset(transcript) >= range - 1
end

local function pointValue(target, fallback)
  if target and target.point ~= nil then
    return target.point
  end
  if target and type(target.GetPoint) == "function" then
    local point, relativeTo, relativePoint, offsetX, offsetY = target:GetPoint(1)
    if point ~= nil then
      return { point, relativeTo, relativePoint, offsetX, offsetY }
    end
  end
  return fallback
end

local function layoutOptions(transcript)
  local options = transcript._virtualLayoutOptions
  if options == nil then
    options = {}
    transcript._virtualLayoutOptions = options
  end
  if transcript._onRevealCensored == nil then
    transcript._onRevealCensored = function()
      TranscriptView.RenderTranscript(transcript, transcript._allMessages)
    end
  end
  options.fallbackClassTag = transcript.fallbackClassTag
  options.senderFallbackClassTag = transcript.senderFallbackClassTag
  local contact = transcript.conversationContact
  options.conversationChannel = contact and contact.channel or nil
  options.conversationDisplayName = contact and contact.displayName or nil
  options.unreadDividerMessage = transcript.unreadDividerMessage
  options.onRevealCensored = transcript._onRevealCensored
  options.onReact = transcript.onReact
  options.canReact = transcript.canReact
  options.chatLocked = transcript.chatLocked
  options.seenReceipts = transcript.seenReceipts
  options.onMessageAction = transcript.onMessageAction
  options.onReply = transcript.onReply
  options.canReply = transcript.canReply
  options.onIgnoreSender = transcript.onIgnoreSender
  options.canIgnoreSender = transcript.canIgnoreSender
  options.onQuoteClick = transcript.onQuoteClick
  options.openPlayerMenu = transcript.openPlayerMenu
  return options
end

-- WoW: Forever gamepad UI (GamepadTranscript): bubbles were laid out.
local function reportNavTargets(transcript)
  if type(transcript.onNavTargetsChanged) == "function" then
    transcript.onNavTargetsChanged()
  end
end

--- renderOptions: FORCE_RENDER for theme changes, RELAYOUT_RENDER for
--- viewport size changes; the per-message row diff sees neither.
function TranscriptView.RenderTranscript(transcript, messages, renderOptions)
  local allMessages = messages or {}
  transcript._allMessages = allMessages

  local paneWidth = sizeValue(transcript.scrollFrame, "GetWidth", "width", 400)
  Virtualization.Render(transcript, allMessages, paneWidth, layoutOptions(transcript), renderOptions)

  transcript.point = pointValue(transcript.scrollFrame, transcript.point)
  transcript.width = sizeValue(transcript.scrollFrame, "GetWidth", "width", transcript.width or 0)
  transcript.height = sizeValue(transcript.scrollFrame, "GetHeight", "height", transcript.height or 0)
  reportNavTargets(transcript)
end

function TranscriptView.RefreshViewport(transcript)
  if Virtualization.RefreshViewport(transcript) then
    reportNavTargets(transcript)
    return true
  end
  return false
end

-- Jump to a quoted message if it is still in history. Best effort: the
-- row offset is the virtualized estimate until that row is laid out.
function TranscriptView.ScrollToReply(transcript, replyTo)
  local state = transcript._virtualState
  local index = MessageReplies.Find(transcript._allMessages, replyTo)
  local row = state and index and state.rows[index]
  if row == nil then
    return false
  end
  ScrollView.SetVerticalScroll(transcript, row.offset - TranscriptRows.CONTENT_PAD)
  TranscriptView.RefreshViewport(transcript)
  return true
end

function TranscriptView.Reset(transcript)
  Virtualization.Reset(transcript)
  transcript._allMessages = nil
end

TranscriptView._pointValue = pointValue
TranscriptView._sizeValue = sizeValue

ns.ConversationPaneTranscriptView = TranscriptView

return TranscriptView
