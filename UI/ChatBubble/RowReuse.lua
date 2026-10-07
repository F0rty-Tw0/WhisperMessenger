local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FramePool = ns.ChatBubbleFramePool or require("WhisperMessenger.UI.ChatBubble.FramePool")

-- Lets a layout pass keep the pooled frames of rows that stay in range, so
-- scrolling builds only the rows that enter the viewport.
local RowReuse = {}

local function dividerOn(row, options)
  return options ~= nil and options.unreadDividerMessage == row.message
end

-- A row laid out by the previous pass can keep its frames when everything it
-- draws from is unchanged: its message (row.stale), same pool, same neighbour
-- above (grouping, date separator), same divider, receipt and width.
local function canKeep(row, index, contentFrame, messages, previousPass, paneWidth, options, seenIndex)
  return not row.stale
    and row.laidOutPass == previousPass
    and row.laidOutGeneration == FramePool.generation(contentFrame)
    and row.laidOutPrevious == messages[index - 1]
    and row.laidOutWidth == paneWidth
    and row.laidOutSeen == (index == seenIndex)
    and row.laidOutDivider == dividerOn(row, options)
end

-- Marks the rows in range that keep their frames (row.keptPass == pass) and
-- returns every other active frame to the pool.
function RowReuse.KeepRows(contentFrame, messages, rows, firstIndex, lastIndex, paneWidth, options, seenIndex, previousPass, pass)
  for index = firstIndex, lastIndex do
    local row = rows[index]
    if canKeep(row, index, contentFrame, messages, previousPass, paneWidth, options, seenIndex) then
      row.keptPass = pass
      for _, frame in ipairs(row.frames) do
        frame._wmKeepMark = pass
      end
    end
  end
  FramePool.releaseUnmarked(contentFrame, pass)
end

-- Puts a kept row back on the active list at its new top. Only frames
-- anchored to the content move; frames anchored to the bubble follow it.
function RowReuse.Restore(row, contentFrame, activeFrames, yOffset)
  local delta = yOffset - row.laidOutTop
  for _, frame in ipairs(row.frames) do
    if delta ~= 0 then
      local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
      if relativeTo == contentFrame then
        frame:ClearAllPoints()
        frame:SetPoint(point, relativeTo, relativePoint, x, y - delta)
      end
    end
    activeFrames[#activeFrames + 1] = frame
  end
end

-- Records the frames a freshly laid out row acquired (row.frameFirst onward).
function RowReuse.Capture(row, activeFrames)
  local frames = row.frames
  if frames == nil then
    frames = {}
    row.frames = frames
  end
  local count = 0
  for i = row.frameFirst, #activeFrames do
    count = count + 1
    frames[count] = activeFrames[i]
  end
  for i = #frames, count + 1, -1 do
    frames[i] = nil
  end
end

-- Remembers what the row was laid out against, for the next pass's canKeep.
function RowReuse.Record(row, index, contentFrame, messages, pass, yOffset, paneWidth, options, seenIndex)
  row.stale = nil
  row.laidOutPass = pass
  row.laidOutGeneration = FramePool.generation(contentFrame)
  row.laidOutTop = yOffset
  row.laidOutPrevious = messages[index - 1]
  row.laidOutWidth = paneWidth
  row.laidOutSeen = index == seenIndex
  row.laidOutDivider = dividerOn(row, options)
end

ns.ChatBubbleRowReuse = RowReuse
return RowReuse
