-- Lays out a whole transcript in one pass: estimates every row, then runs
-- Layout.LayoutRange over all of them. Production lays out only the visible
-- range (TranscriptVirtualization); bubble tests use this to render a full
-- message list without the virtualized scroll view.
local Layout = require("WhisperMessenger.UI.ChatBubble.Layout")

local function LayoutMessages(factory, contentFrame, messages, paneWidth, options)
  messages = messages or {}
  local rows = contentFrame._wmLayoutRows
  if rows == nil then
    rows = {}
    contentFrame._wmLayoutRows = rows
  end
  local offset = 0
  for index, message in ipairs(messages) do
    local row = rows[index]
    if row == nil then
      row = {}
      rows[index] = row
    end
    row.offset = offset
    row.height = Layout.EstimateRowHeight(messages[index - 1], message, paneWidth, index == 1)
    offset = offset + row.height
  end
  for index = #messages + 1, #rows do
    rows[index] = nil
  end
  local totalHeight = Layout.LayoutRange(factory, contentFrame, messages, rows, 1, #messages, paneWidth, options)
  return totalHeight
end

return LayoutMessages
