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
  transcript.point = pointValue(transcript.scrollFrame, nil)
  transcript.width = sizeValue(transcript.scrollFrame, "GetWidth", "width", parentWidth - 32)
  transcript.height = sizeValue(transcript.scrollFrame, "GetHeight", "height", parentHeight - TRANSCRIPT_BOTTOM_GAP)
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