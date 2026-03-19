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

  return string.format("%s: %s", message.playerName or "Unknown", message.text or "")
end

function ConversationPane.RenderTranscript(transcript, messages)
  transcript.lines = {}

  for _, message in ipairs(messages or {}) do
    table.insert(transcript.lines, formatMessage(message))
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

function ConversationPane.Create(factory, parent, selectedContact, conversation)
  local pane = factory.CreateFrame("Frame", nil, parent)
  pane:SetAllPoints(parent)

  local header = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  header:SetText(selectedContact and selectedContact.displayName or "No conversation selected")

  local statusBanner = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusBanner:SetText("")

  local transcript = factory.CreateFrame("Frame", nil, pane)
  transcript.lines = {}

  ConversationPane.RenderTranscript(transcript, conversation and conversation.messages or {})

  return {
    frame = pane,
    header = header,
    statusBanner = statusBanner,
    transcript = transcript,
  }
end

ns.ConversationPane = ConversationPane

return ConversationPane
