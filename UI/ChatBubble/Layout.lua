local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local Layout = {}

local function releaseAllFrames(pool)
  for _, f in ipairs(pool) do
    if f.Hide then
      f:Hide()
    end
  end
end

function Layout.LayoutMessages(factory, contentFrame, messages, paneWidth, options)
  local Grouping = ns.ChatBubbleGrouping or require("WhisperMessenger.UI.ChatBubble.Grouping")
  local BubbleFrame = ns.ChatBubbleBubbleFrame or require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
  local DateSeparator = ns.ChatBubbleDateSeparator or require("WhisperMessenger.UI.ChatBubble.DateSeparator")

  local ShouldGroup = Grouping.ShouldGroup
  local CreateBubble = BubbleFrame.CreateBubble
  local CreateDateSeparator = DateSeparator.CreateDateSeparator

  -- Hide all pooled frames
  contentFrame._bubblePool = contentFrame._bubblePool or {}
  releaseAllFrames(contentFrame._bubblePool)

  local pool = contentFrame._bubblePool
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
        -- Fallback: compare floor(ts / 86400)
        local d1 = math.floor((prevMsg.sentAt or 0) / 86400)
        local d2 = math.floor((message.sentAt or 0) / 86400)
        needsSeparator = d1 ~= d2
      end

      if needsSeparator then
        local sep = CreateDateSeparator(factory, contentFrame, message.sentAt, paneWidth)
        sep.frame:ClearAllPoints()
        sep.frame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
        table.insert(pool, sep.frame)
        yOffset = yOffset + sep.height + BUBBLE_GROUP_SPACING
      end
    end

    -- Determine grouping and spacing
    local grouped = ShouldGroup(prevMsg, message)
    local spacing = grouped and BUBBLE_SPACING or BUBBLE_GROUP_SPACING
    if i == 1 then
      spacing = 0
    end

    yOffset = yOffset + spacing

    -- Show icon on first of a group (both directions)
    local showIcon = (not grouped) and (message.kind ~= "system")

    -- Sender name + timestamp label above first bubble in a group
    if showIcon then
      local nameFrame = factory.CreateFrame("Frame", nil, contentFrame)
      nameFrame:SetSize(paneWidth, 16)
      nameFrame:ClearAllPoints()

      local nameFS = nameFrame:CreateFontString(nil, "OVERLAY")
      setFontObject(nameFS, Theme.FONTS.message_time)
      setTextColor(nameFS, Theme.COLORS.text_secondary)

      -- Timestamp next to sender name
      local timeStr = ""
      if ns.TimeFormat and ns.TimeFormat.MessageTime then
        timeStr = ns.TimeFormat.MessageTime(message.sentAt) or ""
      end
      local timeFS = nameFrame:CreateFontString(nil, "OVERLAY")
      setFontObject(timeFS, Theme.FONTS.message_time)
      setTextColor(timeFS, Theme.COLORS.text_timestamp)
      timeFS:SetText(timeStr)

      if message.direction == "out" then
        nameFS:SetText("You")
        nameFS:SetPoint("RIGHT", nameFrame, "RIGHT", -48, 0)
        timeFS:SetPoint("RIGHT", nameFS, "LEFT", -6, 0)
        nameFrame:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, -yOffset)
      else
        local displayName = message.playerName or message.senderDisplayName or ""
        nameFS:SetText(displayName)
        nameFS:SetPoint("LEFT", nameFrame, "LEFT", 48, 0)
        timeFS:SetPoint("LEFT", nameFS, "RIGHT", 6, 0)
        nameFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
      end
      table.insert(pool, nameFrame)
      yOffset = yOffset + 18
    end

    local fallbackClassTag = options and options.fallbackClassTag or nil
    local bubble = CreateBubble(factory, contentFrame, message, {
      paneWidth = paneWidth,
      showIcon = showIcon,
      isGrouped = grouped,
      fallbackClassTag = fallbackClassTag,
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

    table.insert(pool, bubble.frame)
    yOffset = yOffset + bubble.height

    prevMsg = message
  end

  return yOffset
end

ns.ChatBubbleLayout = Layout
return Layout
