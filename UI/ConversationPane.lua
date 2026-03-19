local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ConversationPane = {}

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

function ConversationPane.RenderTranscript(transcript, messages)
  transcript.lines = {}

  for _, message in ipairs(messages or {}) do
    table.insert(transcript.lines, formatMessage(message))
  end

  if transcript.text then
    transcript.text:SetText(table.concat(transcript.lines, "\n"))
  end

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

  local transcript = factory.CreateFrame("Frame", nil, pane)
  transcript:SetPoint("TOPLEFT", statusBanner, "BOTTOMLEFT", 0, -12)
  transcript:SetSize(parentWidth - 32, parentHeight - 110)
  transcript.lines = {}
  transcript.text = transcript:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  transcript.text:SetPoint("TOPLEFT", transcript, "TOPLEFT", 0, 0)
  if transcript.text.SetWidth then
    transcript.text:SetWidth(sizeValue(transcript, "GetWidth", "width", parentWidth - 32))
  end
  if transcript.text.SetJustifyH then
    transcript.text:SetJustifyH("LEFT")
  end
  if transcript.text.SetJustifyV then
    transcript.text:SetJustifyV("TOP")
  end
  transcript.text:SetText("")

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