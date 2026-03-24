local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")

local Layout = {}

function Layout.LayoutMessages(factory, contentFrame, messages, paneWidth, options)
  local Grouping = ns.ChatBubbleGrouping or require("WhisperMessenger.UI.ChatBubble.Grouping")
  local BubbleFrame = ns.ChatBubbleBubbleFrame or require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
  local DateSeparator = ns.ChatBubbleDateSeparator or require("WhisperMessenger.UI.ChatBubble.DateSeparator")
  local FramePool = ns.ChatBubbleFramePool or require("WhisperMessenger.UI.ChatBubble.FramePool")
  local SenderLabel = ns.ChatBubbleSenderLabel or require("WhisperMessenger.UI.ChatBubble.SenderLabel")

  local ShouldGroup = Grouping.ShouldGroup
  local CreateBubble = BubbleFrame.CreateBubble
  local CreateDateSeparator = DateSeparator.CreateDateSeparator

  FramePool.initPool(contentFrame)
  FramePool.releaseAll(contentFrame)

  -- Wrap factory to route CreateFrame through the pool
  local pooledFactory = {
    CreateFrame = function(frameType, _name, parent)
      return FramePool.acquireFrame(factory, contentFrame, frameType, parent)
    end,
  }

  local yOffset = 0
  local prevMsg = nil

  local BUBBLE_SPACING = Theme.LAYOUT.BUBBLE_SPACING
  local BUBBLE_GROUP_SPACING = Theme.LAYOUT.BUBBLE_GROUP_SPACING

  for i, message in ipairs(messages or {}) do
    -- Date separator check
    if prevMsg then
      local needsSeparator
      if ns.TimeFormat and ns.TimeFormat.IsDifferentDay then
        needsSeparator = ns.TimeFormat.IsDifferentDay(prevMsg.sentAt, message.sentAt)
      else
        local d1 = math.floor((prevMsg.sentAt or 0) / 86400)
        local d2 = math.floor((message.sentAt or 0) / 86400)
        needsSeparator = d1 ~= d2
      end

      if needsSeparator then
        local sep = CreateDateSeparator(pooledFactory, contentFrame, message.sentAt, paneWidth)
        sep.frame:ClearAllPoints()
        sep.frame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
        yOffset = yOffset + sep.height + BUBBLE_GROUP_SPACING
      end
    end

    local grouped = ShouldGroup(prevMsg, message)
    local spacing = grouped and BUBBLE_SPACING or BUBBLE_GROUP_SPACING
    if i == 1 then
      spacing = 0
    end

    yOffset = yOffset + spacing

    local showIcon = (not grouped) and (message.kind ~= "system")

    -- Sender name + timestamp label above first bubble in a group
    if showIcon then
      local label = SenderLabel.CreateSenderLabel(pooledFactory, contentFrame, message, paneWidth, yOffset)
      yOffset = yOffset + label.height
    end

    local fallbackClassTag = options and options.fallbackClassTag or nil
    local bubble = CreateBubble(pooledFactory, contentFrame, message, {
      paneWidth = paneWidth,
      showIcon = showIcon,
      isGrouped = grouped,
      fallbackClassTag = fallbackClassTag,
      iconFactory = pooledFactory,
    })

    -- Re-anchor to content frame at current yOffset
    bubble.frame:ClearAllPoints()
    if message.kind == "system" then
      bubble.frame:SetPoint("TOP", contentFrame, "TOPLEFT", paneWidth / 2, -yOffset)
    elseif message.direction == "out" then
      bubble.frame:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -48, -yOffset)
    else
      bubble.frame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 48, -yOffset)
    end

    -- iconFrame was already acquired through pooledFactory inside CreateBubble
    yOffset = yOffset + bubble.height

    prevMsg = message
  end

  return yOffset
end

ns.ChatBubbleLayout = Layout
return Layout
