local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local TranscriptRows = ns.ConversationPaneTranscriptRows or require("WhisperMessenger.UI.ConversationPane.TranscriptRows")
local CONTENT_PAD = TranscriptRows.CONTENT_PAD

-- Offset math over the transcript's row list: which rows a scroll offset
-- shows, and where a message lands after the rows re-measure.
local TranscriptRowGeometry = {}

local OVERSCAN_ROWS = 2

function TranscriptRowGeometry.TotalHeight(rows)
  local lastRow = rows[#rows]
  if lastRow == nil then
    return 0
  end
  return lastRow.offset + lastRow.height + CONTENT_PAD
end

function TranscriptRowGeometry.RecomputeOffsets(rows, startIndex)
  startIndex = math.max(startIndex or 1, 1)
  local offset = CONTENT_PAD
  if startIndex > 1 then
    local previousRow = rows[startIndex - 1]
    offset = previousRow.offset + previousRow.height
  end
  for index = startIndex, #rows do
    local row = rows[index]
    row.offset = offset
    offset = offset + row.height
  end
  return offset + CONTENT_PAD
end

local function rowAtOffset(rows, offset)
  if #rows == 0 then
    return nil
  end
  local low = 1
  local high = #rows
  while low <= high do
    local middle = math.floor((low + high) / 2)
    if rows[middle].offset <= offset then
      low = middle + 1
    else
      high = middle - 1
    end
  end
  return rows[math.max(math.min(high, #rows), 1)]
end

function TranscriptRowGeometry.RangeForOffset(rows, offset, viewportHeight)
  if #rows == 0 then
    return nil, nil
  end
  local firstVisible = rowAtOffset(rows, offset).index
  local lastVisible = rowAtOffset(rows, offset + math.max(viewportHeight, 0)).index
  return math.max(firstVisible - OVERSCAN_ROWS, 1), math.min(lastVisible + OVERSCAN_ROWS, #rows)
end

local function indexForMessage(rows, message, fallbackIndex)
  if fallbackIndex and rows[fallbackIndex] and rows[fallbackIndex].message == message then
    return fallbackIndex
  end
  for index, row in ipairs(rows) do
    if row.message == message then
      return index
    end
  end
  return nil
end

function TranscriptRowGeometry.CaptureAnchor(rows, offset)
  local row = rowAtOffset(rows, offset)
  if row == nil then
    return nil, 0, nil
  end
  return row.message, offset - row.offset, row.index
end

function TranscriptRowGeometry.AnchoredOffset(rows, message, delta, fallbackIndex)
  local index = indexForMessage(rows, message, fallbackIndex)
  if index == nil then
    return nil
  end
  local row = rows[index]
  local maxDelta = math.max(row.height - 1, 0)
  -- Negative only above the first row, inside the top pad.
  local clampedDelta = math.max(-row.offset, math.min(delta or 0, maxDelta))
  return row.offset + clampedDelta
end

ns.ConversationPaneTranscriptRowGeometry = TranscriptRowGeometry
return TranscriptRowGeometry
