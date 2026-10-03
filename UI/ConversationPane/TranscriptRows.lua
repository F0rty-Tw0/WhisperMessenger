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
  "repeatCount",
  "lastSeenAt",
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

local WEAK_KEYS = { __mode = "k" }

local function newState()
  return { rows = {}, spareRows = {}, rowByMessage = setmetatable({}, WEAK_KEYS), pass = 0 }
end

-- Drops index entries for rows whose message left the transcript, then
-- recycles the old row array as the next pass's spare.
local function retireRows(state, oldRows, pass)
  local rowByMessage = state.rowByMessage
  for index = #oldRows, 1, -1 do
    local row = oldRows[index]
    if row.pass ~= pass and rowByMessage[row.message] == row then
      rowByMessage[row.message] = nil
    end
    oldRows[index] = nil
  end
  state.spareRows = oldRows
end

-- Returns the transcript's virtual state and whether any row changed.
-- Rows follow their message: a cap shift keeps measured heights.
function TranscriptRows.Prepare(transcript, messages, paneWidth, dividerMessage)
  local state = transcript._virtualState
  if state == nil then
    state = newState()
    transcript._virtualState = state
  end

  local oldRows = state.rows
  local rows = state.spareRows
  local rowByMessage = state.rowByMessage
  local pass = state.pass + 1
  state.pass = pass
  local widthChanged = state.paneWidth ~= paneWidth
  local geometryRevision = ChatBubbleLayout.GetGeometryRevision()
  local geometryChanged = state.geometryRevision ~= geometryRevision
  local anyChanged = widthChanged or geometryChanged or #oldRows ~= #messages
  local offset = CONTENT_PAD
  for index, message in ipairs(messages) do
    local row = rowByMessage[message]
    if row == nil then
      row = {}
      rowByMessage[message] = row
    end
    rows[index] = row

    local estimatedHeight = ChatBubbleLayout.EstimateRowHeight(messages[index - 1], message, paneWidth, index == 1, message == dividerMessage)
    local changed = widthChanged or geometryChanged or snapshotChanged(row, message) or row.estimatedHeight ~= estimatedHeight

    if changed then
      row.height = estimatedHeight
      anyChanged = true
    end
    if row.index ~= index then
      anyChanged = true
    end
    row.pass = pass
    row.index = index
    row.message = message
    row.offset = offset
    snapshot(row, message)
    row.estimatedHeight = estimatedHeight
    offset = offset + row.height
  end
  state.rows = rows
  retireRows(state, oldRows, pass)

  state.messages = messages
  state.paneWidth = paneWidth
  state.geometryRevision = geometryRevision
  state.totalHeight = #messages > 0 and offset + CONTENT_PAD or 0
  return state, anyChanged
end

ns.ConversationPaneTranscriptRows = TranscriptRows
return TranscriptRows
