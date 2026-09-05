local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")

local Grouping = ns.ChatBubbleGrouping or require("WhisperMessenger.UI.ChatBubble.Grouping")
local BubbleFrame = ns.ChatBubbleBubbleFrame or require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
local DateSeparator = ns.ChatBubbleDateSeparator or require("WhisperMessenger.UI.ChatBubble.DateSeparator")
local FramePool = ns.ChatBubbleFramePool or require("WhisperMessenger.UI.ChatBubble.FramePool")
local SenderLabel = ns.ChatBubbleSenderLabel or require("WhisperMessenger.UI.ChatBubble.SenderLabel")

local Layout = {}
Layout.MESSAGE_EDGE_INSET = Theme.LAYOUT.MESSAGE_EDGE_INSET

local BUBBLE_SPACING = Theme.LAYOUT.BUBBLE_SPACING
local BUBBLE_GROUP_SPACING = Theme.LAYOUT.BUBBLE_GROUP_SPACING
local DEFAULT_FONT_SIZE = 12
local FONT_LINE_HEIGHT_OFFSET = 4
local ESTIMATED_GLYPH_WIDTH = 7
local SENDER_LABEL_HEIGHT = 18
local geometryRevision = 0
local geometryFontSize
local geometryFontMode
local geometryFontOutline
local geometryLanguage

local function isDifferentDay(previousMessage, message)
  if previousMessage == nil then
    return false
  end
  if ns.TimeFormat and ns.TimeFormat.IsDifferentDay then
    return ns.TimeFormat.IsDifferentDay(previousMessage.sentAt, message.sentAt)
  end
  local previousDay = math.floor((previousMessage.sentAt or 0) / 86400)
  local currentDay = math.floor((message.sentAt or 0) / 86400)
  return previousDay ~= currentDay
end

local function placeBubble(frame, contentFrame, message, paneWidth, yOffset)
  frame:ClearAllPoints()

  if message.kind == "system" then
    frame:SetPoint("TOP", contentFrame, "TOPLEFT", paneWidth / 2, -yOffset)
  elseif message.direction == "out" then
    frame:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -Layout.MESSAGE_EDGE_INSET, -yOffset)
  else
    frame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", Layout.MESSAGE_EDGE_INSET, -yOffset)
  end
end

local function rowPrefixHeight(previousMessage, message, isFirst)
  local grouped = Grouping.ShouldGroup(previousMessage, message)
  local height = 0
  if isDifferentDay(previousMessage, message) then
    height = height + Theme.LAYOUT.DATE_SEPARATOR_HEIGHT + BUBBLE_GROUP_SPACING
  end
  if not isFirst then
    height = height + (grouped and BUBBLE_SPACING or BUBBLE_GROUP_SPACING)
  end
  if not grouped and message.kind ~= "system" then
    height = height + SENDER_LABEL_HEIGHT
  end
  return height
end

function Layout.GetGeometryRevision()
  local fontSize = type(Fonts.GetFontSize) == "function" and Fonts.GetFontSize() or DEFAULT_FONT_SIZE
  local fontMode = type(Fonts.GetMode) == "function" and Fonts.GetMode() or nil
  local fontOutline = type(Fonts.GetOutline) == "function" and Fonts.GetOutline() or nil
  local language = type(Fonts.GetLanguage) == "function" and Fonts.GetLanguage() or nil
  if geometryFontSize ~= fontSize or geometryFontMode ~= fontMode or geometryFontOutline ~= fontOutline or geometryLanguage ~= language then
    geometryRevision = geometryRevision + 1
    geometryFontSize = fontSize
    geometryFontMode = fontMode
    geometryFontOutline = fontOutline
    geometryLanguage = language
  end
  return geometryRevision
end

function Layout.EstimateRowHeight(previousMessage, message, paneWidth, isFirst)
  local kind = message.kind or "user"
  local paddingHorizontal = kind == "system" and 8 or Theme.LAYOUT.BUBBLE_PADDING_H
  local paddingVertical = kind == "system" and 4 or Theme.LAYOUT.BUBBLE_PADDING_V
  local textWidth = math.max(paneWidth * Theme.LAYOUT.BUBBLE_MAX_WIDTH_PCT - paddingHorizontal * 2, 1)
  local fontSize = type(Fonts.GetFontSize) == "function" and Fonts.GetFontSize() or DEFAULT_FONT_SIZE
  local estimatedLineHeight = fontSize + FONT_LINE_HEIGHT_OFFSET
  local charactersPerLine = math.max(math.floor(textWidth / ESTIMATED_GLYPH_WIDTH), 1)
  local text = type(message.text) == "string" and message.text or ""
  local lineCount = math.max(math.ceil(math.max(#text, 1) / charactersPerLine), 1)
  local height = rowPrefixHeight(previousMessage, message, isFirst) + lineCount * estimatedLineHeight + paddingVertical * 2
  if message.isCensored == true then
    height = height + 12
  end
  local reaction = MessageReactions.VisibleReaction(message)
  if kind == "user" and reaction and ReactionAssets.GetTexCoords(reaction.key) then
    height = height + ReactionAssets.GetBadgeOverflow()
  end
  return height
end

-- Index of the sender label that should carry the "Seen" receipt: the start
-- of the group holding the newest seen outgoing message, and only when that
-- whole group has been seen. Newer unseen groups simply show nothing, like
-- other messengers. Returns nil when there is nothing to mark.
local function seenLabelIndex(messages)
  local lastSeen
  for index = #messages, 1, -1 do
    local message = messages[index]
    if message.direction == "out" and message.kind ~= "system" and message.seenAt ~= nil then
      lastSeen = index
      break
    end
  end
  if lastSeen == nil then
    return nil
  end
  local groupStart = lastSeen
  while groupStart > 1 and Grouping.ShouldGroup(messages[groupStart - 1], messages[groupStart]) do
    groupStart = groupStart - 1
  end
  if messages[lastSeen + 1] ~= nil and Grouping.ShouldGroup(messages[lastSeen], messages[lastSeen + 1]) then
    return nil
  end
  return groupStart
end

local function layoutMessage(pooledFactory, factory, contentFrame, messages, index, paneWidth, yOffset, options, seenIndex)
  local message = messages[index]
  local previousMessage = messages[index - 1]
  if isDifferentDay(previousMessage, message) then
    local separator = DateSeparator.CreateDateSeparator(pooledFactory, contentFrame, message.sentAt, paneWidth)
    separator.frame:ClearAllPoints()
    separator.frame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
    yOffset = yOffset + separator.height + BUBBLE_GROUP_SPACING
  end

  local grouped = Grouping.ShouldGroup(previousMessage, message)
  if index > 1 then
    yOffset = yOffset + (grouped and BUBBLE_SPACING or BUBBLE_GROUP_SPACING)
  end

  local showIcon = not grouped and message.kind ~= "system"
  if showIcon then
    local labelOptions = contentFrame._wmLabelOptions
    if labelOptions == nil then
      labelOptions = {}
      contentFrame._wmLabelOptions = labelOptions
    end
    labelOptions.showSeen = index == seenIndex
    local label = SenderLabel.CreateSenderLabel(pooledFactory, contentFrame, message, paneWidth, yOffset, labelOptions)
    yOffset = yOffset + label.height
  end

  local bubbleOptions = contentFrame._wmBubbleOptions
  if bubbleOptions == nil then
    bubbleOptions = {}
    contentFrame._wmBubbleOptions = bubbleOptions
  end
  bubbleOptions.paneWidth = paneWidth
  bubbleOptions.showIcon = showIcon
  bubbleOptions.isGrouped = grouped
  bubbleOptions.fallbackClassTag = options and options.fallbackClassTag or nil
  bubbleOptions.iconFactory = pooledFactory
  bubbleOptions.persistentFactory = factory
  bubbleOptions.onRevealCensored = options and options.onRevealCensored or nil
  bubbleOptions.onReact = options and options.onReact or nil
  bubbleOptions.canReact = options and options.canReact or nil

  local bubble = BubbleFrame.CreateBubble(pooledFactory, contentFrame, message, bubbleOptions)
  bubble.frame._wmVirtualIndex = index
  placeBubble(bubble.frame, contentFrame, message, paneWidth, yOffset)
  return yOffset + bubble.height
end

function Layout.LayoutRange(factory, contentFrame, messages, rows, firstIndex, lastIndex, paneWidth, options)
  FramePool.initPool(contentFrame)
  FramePool.releaseAll(contentFrame)
  if firstIndex == nil or lastIndex == nil or firstIndex > lastIndex then
    return 0, nil
  end

  local pooledFactory = FramePool.getFactory(factory, contentFrame)
  local yOffset = rows[firstIndex].offset
  local firstChanged
  local seenIndex = seenLabelIndex(messages)
  for index = firstIndex, lastIndex do
    local row = rows[index]
    row.offset = yOffset
    local nextOffset = layoutMessage(pooledFactory, factory, contentFrame, messages, index, paneWidth, yOffset, options, seenIndex)
    local measuredHeight = nextOffset - yOffset
    if row.height ~= measuredHeight then
      firstChanged = firstChanged or index
      row.height = measuredHeight
    end
    row.measured = true
    yOffset = nextOffset
  end
  return yOffset, firstChanged
end

function Layout.LayoutMessages(factory, contentFrame, messages, paneWidth, options)
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

ns.ChatBubbleLayout = Layout
return Layout
