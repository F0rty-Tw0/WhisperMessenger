local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local ChatBubble = {}

local function loadModule(name, key)
  if ns[key] then return ns[key] end
  local ok, loaded = pcall(require, name)
  if ok then return loaded end
  error(key .. " module not available")
end

local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")

---------------------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------------------

local function measureTextHeight(fontString, text, maxWidth)
  fontString:SetWidth(maxWidth)
  fontString:SetText(text or "")
  return fontString:GetStringHeight() or 14
end

local function applyColor(region, colorTable)
  if not region or not colorTable then return end
  if region.SetColorTexture then
    region:SetColorTexture(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
  end
end

local function setFontObject(fontString, fontKey)
  local fontObj = _G[fontKey] or fontKey
  if fontString.SetFontObject then
    fontString:SetFontObject(fontObj)
  end
end

local function setTextColor(fontString, colorTable)
  if fontString.SetTextColor and colorTable then
    fontString:SetTextColor(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
  end
end

---------------------------------------------------------------------------
-- ChatBubble.ShouldGroup
---------------------------------------------------------------------------

function ChatBubble.ShouldGroup(prev, current)
  if not prev or not current then return false end
  if prev.direction ~= current.direction then return false end
  if prev.kind == "system" or current.kind == "system" then return false end
  if prev.senderDisplayName ~= current.senderDisplayName then return false end
  if math.abs((current.sentAt or 0) - (prev.sentAt or 0)) > 120 then return false end
  return true
end

---------------------------------------------------------------------------
-- ChatBubble.CreateBubble
---------------------------------------------------------------------------

function ChatBubble.CreateBubble(factory, parent, message, options)
  options = options or {}
  local paneWidth   = options.paneWidth or 400
  local showIcon    = options.showIcon
  local kind        = message.kind or "user"
  local direction   = message.direction or "in"

  local pH = Theme.LAYOUT.BUBBLE_PADDING_H
  local pV = Theme.LAYOUT.BUBBLE_PADDING_V
  local maxBubbleWidth = paneWidth * Theme.LAYOUT.BUBBLE_MAX_WIDTH_PCT

  -- System bubbles use smaller padding
  if kind == "system" then
    pH = 8
    pV = 4
  end

  -- Resolve timestamp string
  local timeStr = ""
  if kind ~= "system" then
    if ns.TimeFormat and ns.TimeFormat.MessageTime then
      timeStr = ns.TimeFormat.MessageTime(message.sentAt) or ""
    end
  end

  -- Create the outer frame
  local frame = factory.CreateFrame("Frame", nil, parent)

  -- Background texture
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(frame)

  -- Message text font string
  local textFS = frame:CreateFontString(nil, "OVERLAY")
  local timestampFS = nil

  if kind == "system" then
    setFontObject(textFS, Theme.FONTS.system_text)
    setTextColor(textFS, Theme.COLORS.text_system)
    applyColor(bg, Theme.COLORS.bg_bubble_system)
  elseif direction == "out" then
    setFontObject(textFS, Theme.FONTS.message_text)
    setTextColor(textFS, Theme.COLORS.text_sent)
    applyColor(bg, Theme.COLORS.bg_bubble_out)
  else
    setFontObject(textFS, Theme.FONTS.message_text)
    setTextColor(textFS, Theme.COLORS.text_received)
    applyColor(bg, Theme.COLORS.bg_bubble_in)
  end

  -- Timestamp font string (user messages only)
  if kind ~= "system" then
    timestampFS = frame:CreateFontString(nil, "OVERLAY")
    setFontObject(timestampFS, Theme.FONTS.message_time)
    setTextColor(timestampFS, Theme.COLORS.text_timestamp)
    if timestampFS.SetText then
      timestampFS:SetText(timeStr)
    end
  end

  -- Measure text width available (account for padding and, for incoming, icon space)
  local iconLeftMargin = 48
  local rightMargin    = 12

  local textAvailWidth
  if kind == "system" then
    textAvailWidth = maxBubbleWidth - pH * 2
  elseif direction == "in" then
    textAvailWidth = maxBubbleWidth - pH * 2
  else
    textAvailWidth = maxBubbleWidth - pH * 2
  end

  -- Measure text height
  local textHeight = measureTextHeight(textFS, message.text, textAvailWidth)

  -- Measure timestamp height/width
  local tsHeight = 0
  local tsWidth  = 0
  if timestampFS then
    timestampFS:SetText(timeStr)
    if timestampFS.GetStringWidth then
      tsWidth = timestampFS:GetStringWidth() or 0
    end
    if timestampFS.GetStringHeight then
      tsHeight = timestampFS:GetStringHeight() or 12
    end
    if tsHeight == 0 then tsHeight = 12 end
  end

  -- Calculate bubble dimensions
  local bubbleInnerWidth  = textAvailWidth
  local bubbleInnerHeight = textHeight + (tsHeight > 0 and (tsHeight + Theme.LAYOUT.MESSAGE_TIMESTAMP_GAP) or 0)
  local bubbleWidth       = bubbleInnerWidth + pH * 2
  local bubbleHeight      = bubbleInnerHeight + pV * 2

  -- Position text inside bubble
  textFS:SetWidth(textAvailWidth)
  textFS:SetText(message.text or "")
  textFS:SetPoint("TOPLEFT", frame, "TOPLEFT", pH, -pV)

  -- Position timestamp at bottom-right inside bubble
  if timestampFS then
    timestampFS:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -pH, pV)
  end

  -- Size the frame
  frame:SetSize(bubbleWidth, bubbleHeight)

  -- Anchor the frame to parent based on direction/kind
  if kind == "system" then
    frame:SetPoint("TOP", parent, "TOPLEFT", paneWidth / 2, 0)
  elseif direction == "out" then
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightMargin, 0)
  else
    -- direction == "in"
    local leftOffset = iconLeftMargin
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", leftOffset, 0)
  end

  -- Class icon for incoming user messages
  local icon = nil
  if direction == "in" and kind == "user" and showIcon then
    icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(Theme.LAYOUT.BUBBLE_ICON_SIZE, Theme.LAYOUT.BUBBLE_ICON_SIZE)
    -- Position at left edge of parent, vertically centered with bubble
    icon:SetPoint("RIGHT", frame, "LEFT", -(iconLeftMargin - Theme.LAYOUT.BUBBLE_ICON_SIZE) / 2 - Theme.LAYOUT.BUBBLE_ICON_SIZE / 2, 0)
    local iconPath = Theme.ClassIcon(message.senderClassTag)
    if not iconPath then
      iconPath = Theme.TEXTURES.bnet_icon
    end
    if icon.SetTexture then
      icon:SetTexture(iconPath)
    end
  end

  -- Total height for layout purposes
  local totalHeight = bubbleHeight

  return {
    frame     = frame,
    bg        = bg,
    text      = textFS,
    timestamp = timestampFS,
    icon      = icon,
    kind      = kind,
    direction = direction,
    height    = totalHeight,
  }
end

---------------------------------------------------------------------------
-- ChatBubble.CreateDateSeparator
---------------------------------------------------------------------------

function ChatBubble.CreateDateSeparator(factory, parent, timestamp, paneWidth)
  local height = Theme.LAYOUT.DATE_SEPARATOR_HEIGHT
  local frame  = factory.CreateFrame("Frame", nil, parent)
  frame:SetSize(paneWidth, height)

  -- Date label
  local labelFS = frame:CreateFontString(nil, "OVERLAY")
  setFontObject(labelFS, Theme.FONTS.date_separator)
  setTextColor(labelFS, Theme.COLORS.text_timestamp)

  local dateStr = ""
  if ns.TimeFormat and ns.TimeFormat.DateSeparator then
    dateStr = ns.TimeFormat.DateSeparator(timestamp) or ""
  end
  if labelFS.SetText then
    labelFS:SetText(dateStr)
  end
  labelFS:SetPoint("CENTER", frame, "CENTER", 0, 0)

  -- Left line
  local lineLeft = frame:CreateTexture(nil, "ARTWORK")
  lineLeft:SetHeight(1)
  applyColor(lineLeft, Theme.COLORS.divider)
  lineLeft:SetPoint("LEFT",  frame,  "LEFT",  16, 0)
  lineLeft:SetPoint("RIGHT", labelFS, "LEFT", -8, 0)

  -- Right line
  local lineRight = frame:CreateTexture(nil, "ARTWORK")
  lineRight:SetHeight(1)
  applyColor(lineRight, Theme.COLORS.divider)
  lineRight:SetPoint("LEFT",  labelFS, "RIGHT",  8, 0)
  lineRight:SetPoint("RIGHT", frame,   "RIGHT", -16, 0)

  return { frame = frame, height = height }
end

---------------------------------------------------------------------------
-- Frame pool helpers
---------------------------------------------------------------------------

local function acquireFrame(pool)
  for i, f in ipairs(pool) do
    if not f:IsShown() then
      table.remove(pool, i)
      f:Show()
      return f
    end
  end
  return nil
end

local function releaseAllFrames(pool)
  for _, f in ipairs(pool) do
    if f.Hide then f:Hide() end
  end
end

---------------------------------------------------------------------------
-- ChatBubble.LayoutMessages
---------------------------------------------------------------------------

function ChatBubble.LayoutMessages(factory, contentFrame, messages, paneWidth)
  -- Hide all pooled frames
  contentFrame._bubblePool = contentFrame._bubblePool or {}
  releaseAllFrames(contentFrame._bubblePool)

  local pool    = contentFrame._bubblePool
  local yOffset = 0
  local prevMsg = nil

  local BUBBLE_SPACING       = Theme.LAYOUT.BUBBLE_SPACING
  local BUBBLE_GROUP_SPACING = Theme.LAYOUT.BUBBLE_GROUP_SPACING

  for i, message in ipairs(messages or {}) do
    -- Date separator check
    if prevMsg then
      local needsSeparator = false
      if ns.TimeFormat and ns.TimeFormat.IsDifferentDay then
        needsSeparator = ns.TimeFormat.IsDifferentDay(prevMsg.sentAt, message.sentAt)
      else
        -- Fallback: compare floor(ts / 86400)
        local d1 = math.floor((prevMsg.sentAt  or 0) / 86400)
        local d2 = math.floor((message.sentAt or 0) / 86400)
        needsSeparator = d1 ~= d2
      end

      if needsSeparator then
        local sep = ChatBubble.CreateDateSeparator(factory, contentFrame, message.sentAt, paneWidth)
        sep.frame:ClearAllPoints()
        sep.frame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -yOffset)
        table.insert(pool, sep.frame)
        yOffset = yOffset + sep.height + BUBBLE_GROUP_SPACING
      end
    end

    -- Determine grouping and spacing
    local grouped  = ChatBubble.ShouldGroup(prevMsg, message)
    local spacing  = grouped and BUBBLE_SPACING or BUBBLE_GROUP_SPACING
    if i == 1 then spacing = 0 end

    yOffset = yOffset + spacing

    -- Show icon only on first of a group (incoming user messages)
    local showIcon = (not grouped) and (message.direction == "in") and (message.kind ~= "system")

    local bubble = ChatBubble.CreateBubble(factory, contentFrame, message, {
      paneWidth = paneWidth,
      showIcon  = showIcon,
      isGrouped = grouped,
    })

    -- Re-anchor to content frame at current yOffset
    bubble.frame:ClearAllPoints()
    if message.kind == "system" then
      bubble.frame:SetPoint("TOP", contentFrame, "TOPLEFT", paneWidth / 2, -yOffset)
    elseif message.direction == "out" then
      bubble.frame:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -12, -yOffset)
    else
      bubble.frame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 48, -yOffset)
    end

    table.insert(pool, bubble.frame)
    yOffset = yOffset + bubble.height

    prevMsg = message
  end

  return yOffset
end

---------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------

ns.ChatBubble = ChatBubble

return ChatBubble
