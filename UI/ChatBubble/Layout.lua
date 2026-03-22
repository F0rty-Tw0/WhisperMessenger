local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local Layout = {}

-- Frame pool: acquire/release pattern to avoid CreateFrame on every render

local function initPool(contentFrame)
  if not contentFrame._freeFrames then
    contentFrame._freeFrames = {}
    contentFrame._activeFrames = {}
    -- Migrate legacy _bubblePool if present
    if contentFrame._bubblePool then
      for _, f in ipairs(contentFrame._bubblePool) do
        if f.Hide then
          f:Hide()
        end
        table.insert(contentFrame._freeFrames, f)
      end
      contentFrame._bubblePool = nil
    end
  end
end

local function acquireFrame(realFactory, contentFrame, frameType, parent)
  local free = contentFrame._freeFrames
  local frame = table.remove(free)
  if frame then
    if frame.Show then
      frame:Show()
    end
    if frame.ClearAllPoints then
      frame:ClearAllPoints()
    end
  else
    frame = realFactory.CreateFrame(frameType, nil, parent)
  end
  table.insert(contentFrame._activeFrames, frame)
  return frame
end

local function hideAllRegions(frame)
  if frame.GetRegions then
    local regions = { frame:GetRegions() }
    for _, r in ipairs(regions) do
      if r.Hide then
        r:Hide()
      end
    end
  end
  if frame.GetChildren then
    local children = { frame:GetChildren() }
    for _, c in ipairs(children) do
      if c.Hide then
        c:Hide()
      end
    end
  end
end

local function releaseAll(contentFrame)
  local active = contentFrame._activeFrames
  local free = contentFrame._freeFrames
  for i = #active, 1, -1 do
    local f = active[i]
    hideAllRegions(f)
    if f.Hide then
      f:Hide()
    end
    if f.ClearAllPoints then
      f:ClearAllPoints()
    end
    table.insert(free, f)
    active[i] = nil
  end
end

function Layout.LayoutMessages(factory, contentFrame, messages, paneWidth, options)
  local Grouping = ns.ChatBubbleGrouping or require("WhisperMessenger.UI.ChatBubble.Grouping")
  local BubbleFrame = ns.ChatBubbleBubbleFrame or require("WhisperMessenger.UI.ChatBubble.BubbleFrame")
  local DateSeparator = ns.ChatBubbleDateSeparator or require("WhisperMessenger.UI.ChatBubble.DateSeparator")

  local ShouldGroup = Grouping.ShouldGroup
  local CreateBubble = BubbleFrame.CreateBubble
  local CreateDateSeparator = DateSeparator.CreateDateSeparator

  initPool(contentFrame)
  releaseAll(contentFrame)

  -- Wrap factory to route CreateFrame through the pool
  local pooledFactory = {
    CreateFrame = function(frameType, name, parent)
      return acquireFrame(factory, contentFrame, frameType, parent)
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
      local nameFrame = acquireFrame(factory, contentFrame, "Frame", contentFrame)
      nameFrame:SetSize(paneWidth, 16)
      nameFrame:ClearAllPoints()

      local nameFS = nameFrame:CreateFontString(nil, "OVERLAY")
      setFontObject(nameFS, Theme.FONTS.message_time)
      setTextColor(nameFS, Theme.COLORS.text_secondary)

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
      yOffset = yOffset + 18
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
