local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatBubbleLayout = ns.ChatBubbleLayout or require("WhisperMessenger.UI.ChatBubble.Layout")

-- Row bookkeeping for the virtualized transcript: one row per message with
-- its estimated height and offset, plus a snapshot of the message fields
-- that change how its bubble renders.
local TranscriptRows = {}

-- Space above the first row and below the last one, inside the scroll
-- content: the viewport is flush with the header and composer lines.
TranscriptRows.CONTENT_PAD = 8
local CONTENT_PAD = TranscriptRows.CONTENT_PAD

-- Copied onto the row as-is; a change in any re-estimates the row.
local MESSAGE_FIELDS = {
  "text",
  "direction",
  "kind",
  "sentAt",
  "playerName",
  "senderDisplayName",
  "senderName",
  "isCensored",
  "seenAt",
  "delivery",
  "replyTo",
  "reaction",
}
local MESSAGE_FIELD_COUNT = #MESSAGE_FIELDS

local function reactionKey(reaction)
  return type(reaction) == "table" and reaction.key or nil
end

local function snapshotChanged(row, message)
  for i = 1, MESSAGE_FIELD_COUNT do
    local field = MESSAGE_FIELDS[i]
    if row[field] ~= message[field] then
      return true
    end
  end
  local pending = message._pendingReaction
  return row.reactionKey ~= reactionKey(message.reaction)
    or row.pendingReaction ~= pending
    or row.pendingReactionKey ~= reactionKey(pending)
    or row.pendingReactionOperation ~= (pending and pending.operation or nil)
end

local function snapshot(row, message)
  for i = 1, MESSAGE_FIELD_COUNT do
    local field = MESSAGE_FIELDS[i]
    row[field] = message[field]
  end
  local pending = message._pendingReaction
  row.reactionKey = reactionKey(message.reaction)
  row.pendingReaction = pending
  row.pendingReactionKey = reactionKey(pending)
  row.pendingReactionOperation = pending and pending.operation or nil
end

-- Returns the transcript's virtual state and whether any row changed.
function TranscriptRows.Prepare(transcript, messages, paneWidth, dividerMessage)
  local state = transcript._virtualState
  if state == nil then
    state = { rows = {} }
    transcript._virtualState = state
  end

  local rows = state.rows
  local widthChanged = state.paneWidth ~= paneWidth
  local geometryRevision = ChatBubbleLayout.GetGeometryRevision()
  local geometryChanged = state.geometryRevision ~= geometryRevision
  local previousRowCount = #rows
  local anyChanged = widthChanged or geometryChanged or previousRowCount ~= #messages
  local offset = CONTENT_PAD
  for index, message in ipairs(messages) do
    local row = rows[index]
    if row == nil then
      row = {}
      rows[index] = row
    end

    local estimatedHeight = ChatBubbleLayout.EstimateRowHeight(messages[index - 1], message, paneWidth, index == 1, message == dividerMessage)
    local changed = widthChanged
      or geometryChanged
      or row.message ~= message
      or snapshotChanged(row, message)
      or row.estimatedHeight ~= estimatedHeight

    if changed then
      row.height = estimatedHeight
      anyChanged = true
    end
    row.index = index
    row.message = message
    row.offset = offset
    snapshot(row, message)
    row.estimatedHeight = estimatedHeight
    offset = offset + row.height
  end
  for index = #messages + 1, #rows do
    rows[index] = nil
  end

  state.messages = messages
  state.paneWidth = paneWidth
  state.geometryRevision = geometryRevision
  state.totalHeight = #messages > 0 and offset + CONTENT_PAD or 0
  return state, anyChanged
end

ns.ConversationPaneTranscriptRows = TranscriptRows
return TranscriptRows
