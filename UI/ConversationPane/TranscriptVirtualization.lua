local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatBubbleLayout = ns.ChatBubbleLayout or require("WhisperMessenger.UI.ChatBubble.Layout")
local FramePool = ns.ChatBubbleFramePool or require("WhisperMessenger.UI.ChatBubble.FramePool")
local ScrollView = ns.ScrollView or require("WhisperMessenger.UI.ScrollView")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local sizeValue = UIHelpers.sizeValue

local TranscriptVirtualization = {}

local OVERSCAN_ROWS = 2
local END_TOLERANCE = 1

local function totalHeight(rows)
  local lastRow = rows[#rows]
  if lastRow == nil then
    return 0
  end
  return lastRow.offset + lastRow.height
end

local function recomputeOffsets(rows, startIndex)
  startIndex = math.max(startIndex or 1, 1)
  local offset = 0
  if startIndex > 1 then
    local previousRow = rows[startIndex - 1]
    offset = previousRow.offset + previousRow.height
  end
  for index = startIndex, #rows do
    local row = rows[index]
    row.offset = offset
    offset = offset + row.height
  end
  return offset
end

local function reactionKey(reaction)
  return type(reaction) == "table" and reaction.key or nil
end

local function prepareRows(transcript, messages, paneWidth)
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
  local offset = 0
  for index, message in ipairs(messages) do
    local row = rows[index]
    if row == nil then
      row = {}
      rows[index] = row
    end

    local estimatedHeight = ChatBubbleLayout.EstimateRowHeight(messages[index - 1], message, paneWidth, index == 1)
    local changed = widthChanged
      or geometryChanged
      or row.message ~= message
      or row.text ~= message.text
      or row.direction ~= message.direction
      or row.kind ~= message.kind
      or row.sentAt ~= message.sentAt
      or row.playerName ~= message.playerName
      or row.senderDisplayName ~= message.senderDisplayName
      or row.senderName ~= message.senderName
      or row.isCensored ~= message.isCensored
      or row.seenAt ~= message.seenAt
      or row.reaction ~= message.reaction
      or row.reactionKey ~= reactionKey(message.reaction)
      or row.pendingReaction ~= message._pendingReaction
      or row.pendingReactionKey ~= reactionKey(message._pendingReaction)
      or row.pendingReactionOperation ~= (message._pendingReaction and message._pendingReaction.operation or nil)
      or row.estimatedHeight ~= estimatedHeight

    if changed then
      row.height = estimatedHeight
      row.measured = false
      anyChanged = true
    end
    row.index = index
    row.message = message
    row.offset = offset
    row.text = message.text
    row.direction = message.direction
    row.kind = message.kind
    row.sentAt = message.sentAt
    row.playerName = message.playerName
    row.senderDisplayName = message.senderDisplayName
    row.senderName = message.senderName
    row.isCensored = message.isCensored
    row.seenAt = message.seenAt
    row.reaction = message.reaction
    row.reactionKey = reactionKey(message.reaction)
    row.pendingReaction = message._pendingReaction
    row.pendingReactionKey = reactionKey(message._pendingReaction)
    row.pendingReactionOperation = message._pendingReaction and message._pendingReaction.operation or nil
    row.estimatedHeight = estimatedHeight
    offset = offset + row.height
  end
  for index = #messages + 1, #rows do
    rows[index] = nil
  end

  state.messages = messages
  state.paneWidth = paneWidth
  state.geometryRevision = geometryRevision
  state.totalHeight = offset
  transcript._virtualRows = rows
  return state, anyChanged
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

local function rangeForOffset(rows, offset, viewportHeight)
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

local function captureAnchor(rows, offset)
  local row = rowAtOffset(rows, offset)
  if row == nil then
    return nil, 0, nil
  end
  return row.message, offset - row.offset, row.index
end

local function anchoredOffset(rows, message, delta, fallbackIndex)
  local index = indexForMessage(rows, message, fallbackIndex)
  if index == nil then
    return nil
  end
  local row = rows[index]
  local maxDelta = math.max(row.height - 1, 0)
  local clampedDelta = math.max(0, math.min(delta or 0, maxDelta))
  return row.offset + clampedDelta
end

local function isAtEnd(transcript)
  local range = ScrollView.GetRange(transcript)
  return range <= 0 or ScrollView.GetOffset(transcript) >= range - END_TOLERANCE
end

-- Returns totalHeight, relaidOut. relaidOut is false when the visible range is
-- unchanged and `force` is not set, which is the allocation-free skip path the
-- background status refresh takes when nothing about the conversation changed.
local function bindOffset(transcript, state, requestedOffset, snapToEnd, force)
  if transcript._renderingViewport then
    return state.totalHeight, false
  end

  local rows = state.rows
  if #rows == 0 then
    FramePool.initPool(transcript.content)
    FramePool.releaseAll(transcript.content)
    transcript._virtualFirstIndex = nil
    transcript._virtualLastIndex = nil
    transcript._renderingViewport = true
    ScrollView.RefreshMetrics(transcript, 0, false)
    state.totalHeight = 0
    transcript._renderingViewport = false
    return state.totalHeight, true
  end

  local viewportHeight = sizeValue(transcript.scrollFrame, "GetHeight", "height", transcript.viewportHeight or 0)
  if viewportHeight <= 0 then
    viewportHeight = transcript.viewportHeight or 0
  end
  local targetOffset = snapToEnd and math.max(state.totalHeight - viewportHeight, 0) or requestedOffset
  local anchorMessage, anchorDelta, anchorIndex = captureAnchor(rows, targetOffset)
  local firstIndex, lastIndex = rangeForOffset(rows, targetOffset, viewportHeight)
  if not force and firstIndex == state.firstIndex and lastIndex == state.lastIndex then
    return state.totalHeight, false
  end

  transcript._renderingViewport = true
  local settled = false
  local passCap = #rows + 1
  for _ = 1, passCap do
    local _, firstChanged = ChatBubbleLayout.LayoutRange(
      transcript.factory,
      transcript.content,
      state.messages,
      rows,
      firstIndex,
      lastIndex,
      state.paneWidth,
      state.options
    )
    if firstChanged then
      state.totalHeight = recomputeOffsets(rows, firstChanged)
    else
      state.totalHeight = totalHeight(rows)
    end

    if snapToEnd then
      targetOffset = math.max(state.totalHeight - viewportHeight, 0)
    else
      targetOffset = anchoredOffset(rows, anchorMessage, anchorDelta, anchorIndex) or targetOffset
    end

    local nextFirst, nextLast = rangeForOffset(rows, targetOffset, viewportHeight)
    state.firstIndex = firstIndex
    state.lastIndex = lastIndex
    transcript._virtualFirstIndex = firstIndex
    transcript._virtualLastIndex = lastIndex
    if nextFirst == firstIndex and nextLast == lastIndex then
      settled = true
      break
    end
    firstIndex = nextFirst
    lastIndex = nextLast
  end

  if not settled then
    local _, firstChanged = ChatBubbleLayout.LayoutRange(
      transcript.factory,
      transcript.content,
      state.messages,
      rows,
      firstIndex,
      lastIndex,
      state.paneWidth,
      state.options
    )
    if firstChanged then
      state.totalHeight = recomputeOffsets(rows, firstChanged)
    else
      state.totalHeight = totalHeight(rows)
    end
    if snapToEnd then
      targetOffset = math.max(state.totalHeight - viewportHeight, 0)
    else
      targetOffset = anchoredOffset(rows, anchorMessage, anchorDelta, anchorIndex) or targetOffset
    end
    state.firstIndex = firstIndex
    state.lastIndex = lastIndex
    transcript._virtualFirstIndex = firstIndex
    transcript._virtualLastIndex = lastIndex
  end

  local measuredTotalHeight = state.totalHeight
  ScrollView.RefreshMetrics(transcript, measuredTotalHeight, snapToEnd)
  state.totalHeight = measuredTotalHeight
  if not snapToEnd then
    ScrollView.SetVerticalScroll(transcript, targetOffset)
  end
  transcript._renderingViewport = false
  return state.totalHeight, true
end

function TranscriptVirtualization.Render(transcript, messages, paneWidth, options, renderOptions)
  local previousState = transcript._virtualState
  local previousRows = previousState and previousState.rows or nil
  local previousOffset = ScrollView.GetOffset(transcript)
  local hadRows = previousRows ~= nil and #previousRows > 0
  local forceSnapToEnd = transcript._virtualForceEnd == true
  transcript._virtualForceEnd = nil
  local snapToEnd = forceSnapToEnd or not hadRows or isAtEnd(transcript)
  local anchorMessage, anchorDelta, anchorIndex
  if hadRows and not snapToEnd then
    anchorMessage, anchorDelta, anchorIndex = captureAnchor(previousRows, previousOffset)
  end

  local state, anyChanged = prepareRows(transcript, messages, paneWidth)
  state.options = options
  local fallbackClassTag = options and options.fallbackClassTag or nil
  -- Bubble geometry is keyed off the row diff, but the fallback class tag only
  -- recolors sender names, so it is tracked separately.
  local force = (renderOptions and renderOptions.force == true)
    or not hadRows
    or forceSnapToEnd
    or anyChanged
    or state.fallbackClassTag ~= fallbackClassTag
  state.fallbackClassTag = fallbackClassTag

  local targetOffset = previousOffset
  if anchorMessage then
    targetOffset = anchoredOffset(state.rows, anchorMessage, anchorDelta, anchorIndex) or targetOffset
  end
  local _, relaidOut = bindOffset(transcript, state, targetOffset, snapToEnd, force)

  local settledWidth = sizeValue(transcript.scrollFrame, "GetWidth", "width", paneWidth)
  if settledWidth ~= paneWidth then
    local settledChanged
    state, settledChanged = prepareRows(transcript, messages, settledWidth)
    state.options = options
    state.fallbackClassTag = fallbackClassTag
    local _, settledRelaidOut = bindOffset(transcript, state, ScrollView.GetOffset(transcript), snapToEnd, force or settledChanged)
    relaidOut = relaidOut or settledRelaidOut
  end
  return state.totalHeight, state.firstIndex, state.lastIndex, relaidOut
end

function TranscriptVirtualization.RefreshViewport(transcript)
  local state = transcript and transcript._virtualState or nil
  if state == nil or transcript._renderingViewport then
    return false
  end
  local offset = ScrollView.GetOffset(transcript)
  local firstIndex, lastIndex = rangeForOffset(state.rows, offset, transcript.viewportHeight or 0)
  if firstIndex == state.firstIndex and lastIndex == state.lastIndex then
    return false
  end
  bindOffset(transcript, state, offset, isAtEnd(transcript), false)
  return true
end

function TranscriptVirtualization.Reset(transcript)
  transcript._virtualState = nil
  transcript._virtualRows = nil
  transcript._virtualFirstIndex = nil
  transcript._virtualLastIndex = nil
end

ns.ConversationPaneTranscriptVirtualization = TranscriptVirtualization
return TranscriptVirtualization
