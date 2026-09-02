local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local Hyperlinks = ns.UIHyperlinks or require("WhisperMessenger.UI.Hyperlinks")
local Virtualization = ns.ConversationPaneTranscriptVirtualization or require("WhisperMessenger.UI.ConversationPane.TranscriptVirtualization")
local sizeValue = UIHelpers.sizeValue

local TranscriptView = {}

local TRANSCRIPT_LINE_HEIGHT = 16
TranscriptView.TRANSCRIPT_SCROLL_STEP = 24
TranscriptView.TRANSCRIPT_BOTTOM_GAP = 56

local function formatMessage(message)
  local body = Hyperlinks.FormatTextForDisplay(message and message.text or "")

  if message.kind == "system" then
    return "[System] " .. body
  end
  if message.direction == "out" then
    return "You: " .. body
  end
  return body
end

local function legacyMessage(message)
  local body = message and message.text or ""
  if message.kind == "system" then
    return "[System] " .. body
  end
  if message.direction == "out" then
    return "You: " .. body
  end
  return body
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
  local appliedWidth

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

local function updateLines(transcript, messages, useHyperlinks)
  local lines = transcript.lines
  if lines == nil then
    lines = {}
    transcript.lines = lines
  end
  for index, message in ipairs(messages) do
    if useHyperlinks then
      lines[index] = formatMessage(message)
    else
      lines[index] = message.text or ""
    end
  end
  for index = #messages + 1, #lines do
    lines[index] = nil
  end
  return lines
end

local function updateVisibleLegacyText(transcript)
  if transcript.text == nil then
    return
  end
  local firstIndex = transcript._virtualFirstIndex
  local lastIndex = transcript._virtualLastIndex
  local visibleLines = transcript._visibleLegacyLines
  if visibleLines == nil then
    visibleLines = {}
    transcript._visibleLegacyLines = visibleLines
  end
  local count = 0
  if firstIndex and lastIndex then
    for index = firstIndex, lastIndex do
      count = count + 1
      local line = legacyMessage(transcript._allMessages[index])
      transcript.lines[index] = line
      visibleLines[count] = line
    end
  end
  for index = count + 1, #visibleLines do
    visibleLines[index] = nil
  end
  transcript.text:SetText(table.concat(visibleLines, "\n"))
  if transcript.text.Hide then
    transcript.text:Hide()
  end
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
  options.onRevealCensored = transcript._onRevealCensored
  options.onReact = transcript.onReact
  options.canReact = transcript.canReact
  return options
end

--- renderOptions may carry { force = true } for callers that change the
--- viewport size or theme colors, which the per-message row diff cannot see.
function TranscriptView.RenderTranscript(transcript, messages, renderOptions)
  local allMessages = messages or {}
  transcript._allMessages = allMessages

  if not transcript.factory then
    local lines = updateLines(transcript, allMessages, true)
    if transcript.text then
      transcript.text:SetText(table.concat(lines, "\n"))
    end
    updateTranscriptLayout(transcript, true)
    return lines
  end

  local lines = updateLines(transcript, allMessages, false)
  local paneWidth = sizeValue(transcript.scrollFrame, "GetWidth", "width", 400)
  local _, _, _, relaidOut = Virtualization.Render(transcript, allMessages, paneWidth, layoutOptions(transcript), renderOptions)
  if relaidOut then
    updateVisibleLegacyText(transcript)
  end

  if transcript.text and transcript.text.SetWidth then
    transcript.text:SetWidth(sizeValue(transcript.scrollFrame, "GetWidth", "width", paneWidth))
  end
  transcript.point = pointValue(transcript.scrollFrame, transcript.point)
  transcript.width = sizeValue(transcript.scrollFrame, "GetWidth", "width", transcript.width or 0)
  transcript.height = sizeValue(transcript.scrollFrame, "GetHeight", "height", transcript.height or 0)
  return lines
end

function TranscriptView.RefreshViewport(transcript)
  if Virtualization.RefreshViewport(transcript) then
    updateVisibleLegacyText(transcript)
    return true
  end
  return false
end

function TranscriptView.Reset(transcript)
  Virtualization.Reset(transcript)
  transcript._allMessages = nil
end

TranscriptView._pointValue = pointValue
TranscriptView._updateTranscriptLayout = updateTranscriptLayout
TranscriptView._sizeValue = sizeValue

ns.ConversationPaneTranscriptView = TranscriptView

return TranscriptView
