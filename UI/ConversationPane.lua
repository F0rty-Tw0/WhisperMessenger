local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationPane = {}
local TRANSCRIPT_LINE_HEIGHT = 16
local TRANSCRIPT_SCROLL_STEP = 24
local TRANSCRIPT_BOTTOM_GAP = 56

local function loadModule(name, key)
  if ns[key] then
    return ns[key]
  end

  local ok, loaded = pcall(require, name)
  if ok then
    return loaded
  end

  error(key .. " module not available")
end

local ScrollView = loadModule("WhisperMessenger.UI.ScrollView", "ScrollView")

local function formatMessage(message)
  if message.kind == "system" then
    return "[System] " .. (message.text or "")
  end

  if message.direction == "out" then
    return "You: " .. (message.text or "")
  end

  return message.text or ""
end

local function headerTextFor(selectedContact)
  if selectedContact and selectedContact.displayName then
    return selectedContact.displayName
  end

  return "No conversation selected"
end

local function sizeValue(target, getterName, fieldName, fallback)
  if target and type(target[getterName]) == "function" then
    local value = target[getterName](target)
    if type(value) == "number" and value > 0 then
      return value
    end
  end

  if target and type(target[fieldName]) == "number" then
    return target[fieldName]
  end

  return fallback
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

local function updateTranscriptLayout(transcript, snapToEnd)
  local scrollFrame = transcript.scrollFrame or transcript
  local transcriptWidth = sizeValue(scrollFrame, "GetWidth", "width", 0)

  if transcript.text and transcript.text.SetWidth then
    transcript.text:SetWidth(transcriptWidth)
  end

  ScrollView.RefreshMetrics(transcript, transcriptContentHeight(transcript), snapToEnd == true)
  transcript.point = scrollFrame and scrollFrame.point or transcript.point
  transcript.width = sizeValue(scrollFrame, "GetWidth", "width", transcript.width or 0)
  transcript.height = sizeValue(scrollFrame, "GetHeight", "height", transcript.height or 0)
end

function ConversationPane.RenderTranscript(transcript, messages)
  transcript.lines = {}

  for _, message in ipairs(messages or {}) do
    table.insert(transcript.lines, formatMessage(message))
  end

  if transcript.text then
    transcript.text:SetText(table.concat(transcript.lines, "\n"))
  end

  updateTranscriptLayout(transcript, true)
  return transcript.lines
end

function ConversationPane.SetStatus(view, status)
  if view.statusBanner == nil then
    return nil
  end

  view.statusBanner:SetText(status and status.status or "")
  return view.statusBanner.text
end

function ConversationPane.Refresh(view, selectedContact, conversation, status)
  view.header:SetText(headerTextFor(selectedContact))
  ConversationPane.RenderTranscript(view.transcript, conversation and conversation.messages or {})
  ConversationPane.SetStatus(view, status)
  return view
end

function ConversationPane.Create(factory, parent, selectedContact, conversation)
  local pane = factory.CreateFrame("Frame", nil, parent)
  local parentWidth = sizeValue(parent, "GetWidth", "width", 600)
  local parentHeight = sizeValue(parent, "GetHeight", "height", 420)
  pane:SetAllPoints(parent)

  local header = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  header:SetPoint("TOPLEFT", pane, "TOPLEFT", 16, -16)
  header:SetText(headerTextFor(selectedContact))

  local statusBanner = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusBanner:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
  statusBanner:SetText("")

  local transcript = ScrollView.Create(factory, pane, {
    width = parentWidth - 32,
    height = parentHeight - TRANSCRIPT_BOTTOM_GAP,
    point = { "TOPLEFT", statusBanner, "BOTTOMLEFT", 0, -12 },
    step = TRANSCRIPT_SCROLL_STEP,
  })
  transcript.point = transcript.scrollFrame and transcript.scrollFrame.point or nil
  transcript.width = sizeValue(transcript.scrollFrame, "GetWidth", "width", parentWidth - 32)
  transcript.height = sizeValue(transcript.scrollFrame, "GetHeight", "height", parentHeight - TRANSCRIPT_BOTTOM_GAP)
  transcript.text = transcript.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  transcript.text:SetPoint("TOPLEFT", transcript.content, "TOPLEFT", 0, 0)
  if transcript.text.SetWidth then
    transcript.text:SetWidth(sizeValue(transcript.scrollFrame, "GetWidth", "width", parentWidth - 32))
  end
  if transcript.text.SetJustifyH then
    transcript.text:SetJustifyH("LEFT")
  end
  if transcript.text.SetJustifyV then
    transcript.text:SetJustifyV("TOP")
  end
  transcript.text:SetText("")
  transcript.lines = {}
  updateTranscriptLayout(transcript, false)

  local view = {
    frame = pane,
    header = header,
    statusBanner = statusBanner,
    transcript = transcript,
  }

  ConversationPane.Refresh(view, selectedContact, conversation)
  return view
end

ns.ConversationPane = ConversationPane

return ConversationPane