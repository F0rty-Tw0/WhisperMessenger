local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue

local TranscriptView = {}

local TRANSCRIPT_LINE_HEIGHT = 16
TranscriptView.TRANSCRIPT_SCROLL_STEP = 24
TranscriptView.TRANSCRIPT_BOTTOM_GAP = 56
TranscriptView.MESSAGES_PAGE_SIZE = 10

local MESSAGES_PAGE_SIZE = TranscriptView.MESSAGES_PAGE_SIZE

local function formatMessage(message)
  if message.kind == "system" then
    return "[System] " .. (message.text or "")
  end

  if message.direction == "out" then
    return "You: " .. (message.text or "")
  end

  return message.text or ""
end

local function transcriptContentHeight(transcript)
  if transcript.text and type(transcript.text.GetStringHeight) == "function" then
    local measuredHeight = transcript.text:GetStringHeight()
    if type(measuredHeight) == "number" and measuredHeight > 0 then
      return measuredHeight
    end
  end

  return math.max(#(transcript.lines or {}), 1) * TRANSCRIPT_LINE_HEIGHT
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

local function updateTranscriptLayout(transcript, snapToEnd)
  local scrollFrame = transcript.scrollFrame or transcript
  local appliedWidth = nil

  for _ = 1, 3 do
    local transcriptWidth = sizeValue(scrollFrame, "GetWidth", "width", 0)

    if transcript.text and transcript.text.SetWidth and transcriptWidth ~= appliedWidth then
      transcript.text:SetWidth(transcriptWidth)
      appliedWidth = transcriptWidth
    end

    ScrollView.RefreshMetrics(transcript, transcriptContentHeight(transcript), snapToEnd == true)

    local settledWidth = sizeValue(scrollFrame, "GetWidth", "width", transcriptWidth)
    if transcript.text == nil or transcript.text.SetWidth == nil or settledWidth == appliedWidth then
      break
    end
  end

  transcript.point = pointValue(scrollFrame, transcript.point)
  transcript.width = sizeValue(scrollFrame, "GetWidth", "width", transcript.width or 0)
  transcript.height = sizeValue(scrollFrame, "GetHeight", "height", transcript.height or 0)
end

function TranscriptView.RenderTranscript(transcript, messages)
  local allMessages = messages or {}
  transcript.lines = {}

  for _, message in ipairs(allMessages) do
    table.insert(transcript.lines, formatMessage(message))
  end

  -- Determine visible slice (last N messages)
  local totalCount = #allMessages
  transcript._allMessages = allMessages
  transcript._visibleCount = transcript._visibleCount or MESSAGES_PAGE_SIZE
  if transcript._visibleCount > totalCount then
    transcript._visibleCount = totalCount
  end

  local startIndex = math.max(1, totalCount - transcript._visibleCount + 1)
  local visibleMessages = {}
  for i = startIndex, totalCount do
    table.insert(visibleMessages, allMessages[i])
  end

  if not transcript.factory then
    local visibleLines = {}
    for i = startIndex, totalCount do
      table.insert(visibleLines, transcript.lines[i])
    end
    if transcript.text then
      transcript.text:SetText(table.concat(visibleLines, "\n"))
    end
    updateTranscriptLayout(transcript, true)
    return transcript.lines
  end

  -- Keep legacy text content (for accessibility / backward compat) but hide renderer
  if transcript.text then
    transcript.text:SetText(table.concat(transcript.lines, "\n"))
    if transcript.text.Hide then
      transcript.text:Hide()
    end
  end

  -- ChatBubble loaded lazily since it may not be available at module load time
  local ChatBubble = ns.ChatBubble or require("WhisperMessenger.UI.ChatBubble")
  local paneWidth = sizeValue(transcript.scrollFrame, "GetWidth", "width", 400)
  local totalHeight = ChatBubble.LayoutMessages(transcript.factory, transcript.content, visibleMessages, paneWidth, {
    fallbackClassTag = transcript.fallbackClassTag,
  })

  ScrollView.RefreshMetrics(transcript, totalHeight, true)

  -- Sync legacy text width with viewport for backward compat
  if transcript.text and transcript.text.SetWidth then
    transcript.text:SetWidth(sizeValue(transcript.scrollFrame, "GetWidth", "width", paneWidth))
  end

  transcript.point = pointValue(transcript.scrollFrame, transcript.point)
  transcript.width = sizeValue(transcript.scrollFrame, "GetWidth", "width", transcript.width or 0)
  transcript.height = sizeValue(transcript.scrollFrame, "GetHeight", "height", transcript.height or 0)

  return transcript.lines
end

function TranscriptView.HasMore(transcript)
  if not transcript._allMessages then
    return false
  end
  return (transcript._visibleCount or 0) < #transcript._allMessages
end

function TranscriptView.LoadMore(transcript)
  if not TranscriptView.HasMore(transcript) then
    return false
  end
  transcript._visibleCount = (transcript._visibleCount or MESSAGES_PAGE_SIZE) + MESSAGES_PAGE_SIZE
  TranscriptView.RenderTranscript(transcript, transcript._allMessages)
  return true
end

-- Export pointValue and updateTranscriptLayout for use by the facade (ConversationPane.Create)
TranscriptView._pointValue = pointValue
TranscriptView._updateTranscriptLayout = updateTranscriptLayout
TranscriptView._sizeValue = sizeValue
TranscriptView._ScrollView = ScrollView

ns.ConversationPaneTranscriptView = TranscriptView

return TranscriptView
