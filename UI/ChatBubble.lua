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
  if (prev.playerName or prev.senderDisplayName) ~= (current.playerName or current.senderDisplayName) then return false end
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

  -- Create the outer frame
  local frame = factory.CreateFrame("Frame", nil, parent)

  local CORNER_R = 8
  local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall"

  -- Build a solid-color rounded rectangle from 9 texture regions:
  -- center rect, 4 edge strips, 4 quarter-circle corners
  local bgCenter = frame:CreateTexture(nil, "BACKGROUND")
  bgCenter:SetPoint("TOPLEFT", frame, "TOPLEFT", CORNER_R, -CORNER_R)
  bgCenter:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CORNER_R, CORNER_R)

  local bgTop = frame:CreateTexture(nil, "BACKGROUND")
  bgTop:SetPoint("TOPLEFT", frame, "TOPLEFT", CORNER_R, 0)
  bgTop:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -CORNER_R, 0)
  bgTop:SetHeight(CORNER_R)

  local bgBottom = frame:CreateTexture(nil, "BACKGROUND")
  bgBottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", CORNER_R, 0)
  bgBottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CORNER_R, 0)
  bgBottom:SetHeight(CORNER_R)

  local bgLeft = frame:CreateTexture(nil, "BACKGROUND")
  bgLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -CORNER_R)
  bgLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, CORNER_R)
  bgLeft:SetWidth(CORNER_R)

  local bgRight = frame:CreateTexture(nil, "BACKGROUND")
  bgRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -CORNER_R)
  bgRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, CORNER_R)
  bgRight:SetWidth(CORNER_R)

  -- Quarter-circle corners (cut from a circle texture via TexCoord)
  local function makeCorner(point, relPoint)
    local c = frame:CreateTexture(nil, "BACKGROUND")
    c:SetSize(CORNER_R, CORNER_R)
    c:SetPoint(point, frame, point, 0, 0)
    if c.SetTexture then c:SetTexture(CIRCLE_TEX) end
    return c
  end

  local cTL = makeCorner("TOPLEFT")
  local cTR = makeCorner("TOPRIGHT")
  local cBL = makeCorner("BOTTOMLEFT")
  local cBR = makeCorner("BOTTOMRIGHT")

  -- Set TexCoord to select the correct quarter of the circle
  if cTL.SetTexCoord then
    cTL:SetTexCoord(0, 0.5, 0, 0.5)       -- top-left quarter
    cTR:SetTexCoord(0.5, 1, 0, 0.5)       -- top-right quarter
    cBL:SetTexCoord(0, 0.5, 0.5, 1)       -- bottom-left quarter
    cBR:SetTexCoord(0.5, 1, 0.5, 1)       -- bottom-right quarter
  end

  local bgFills = { bgCenter, bgTop, bgBottom, bgLeft, bgRight }
  local bgCorners = { cTL, cTR, cBL, cBR }

  local function applyBubbleColor(colorTable)
    local r, g, b, a = colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1
    -- Flat fill pieces: solid color rectangles
    for _, part in ipairs(bgFills) do
      if part.SetColorTexture then
        part:SetColorTexture(r, g, b, a)
      end
    end
    -- Corner pieces: tint the circle texture (do NOT overwrite with SetColorTexture)
    for _, part in ipairs(bgCorners) do
      if part.SetVertexColor then
        part:SetVertexColor(r, g, b, a)
      end
    end
  end

  -- Message text font string
  local textFS = frame:CreateFontString(nil, "OVERLAY")

  if kind == "system" then
    setFontObject(textFS, Theme.FONTS.system_text)
    setTextColor(textFS, Theme.COLORS.text_system)
    applyBubbleColor(Theme.COLORS.bg_bubble_system)
  elseif direction == "out" then
    setFontObject(textFS, Theme.FONTS.message_text)
    setTextColor(textFS, Theme.COLORS.text_sent)
    applyBubbleColor(Theme.COLORS.bg_bubble_out)
  else
    setFontObject(textFS, Theme.FONTS.message_text)
    setTextColor(textFS, Theme.COLORS.text_received)
    applyBubbleColor(Theme.COLORS.bg_bubble_in)
  end

  -- Measure text width available (account for padding)
  local iconLeftMargin = 48
  local rightMargin    = 12
  local textAvailWidth = maxBubbleWidth - pH * 2

  -- Measure text at max width first (for proper wrapping / height calc)
  local textHeight = measureTextHeight(textFS, message.text, textAvailWidth)

  -- Shrink bubble to fit text when possible
  local textColumnWidth = textAvailWidth
  if type(textFS.GetStringWidth) == "function" then
    local rawWidth = textFS:GetStringWidth() or 0
    if rawWidth > 0 then
      textColumnWidth = math.min(rawWidth, textAvailWidth)
    end
  end

  -- Re-measure height at the actual column width (may differ if narrower)
  if textColumnWidth < textAvailWidth then
    textHeight = measureTextHeight(textFS, message.text, textColumnWidth)
  end

  -- Calculate bubble dimensions (no timestamp inside bubble)
  local bubbleInnerWidth  = textColumnWidth
  local bubbleInnerHeight = textHeight
  local bubbleWidth       = bubbleInnerWidth + pH * 2
  local bubbleHeight      = bubbleInnerHeight + pV * 2

  -- Position text inside bubble (left-aligned)
  textFS:SetWidth(textColumnWidth)
  textFS:SetJustifyH("LEFT")
  textFS:SetText(message.text or "")
  textFS:SetPoint("TOPLEFT", frame, "TOPLEFT", pH, -pV)

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

  -- Class icon for user messages (both sent and received)
  local icon = nil
  if kind == "user" and showIcon then
    icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetSize(Theme.LAYOUT.BUBBLE_ICON_SIZE, Theme.LAYOUT.BUBBLE_ICON_SIZE)
    if direction == "in" then
      icon:SetPoint("TOPRIGHT", frame, "TOPLEFT", -8, 0)
    else
      icon:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
    end
    local iconPath
    if direction == "out" then
      -- Player's own class icon
      if type(_G.UnitClass) == "function" then
        local _, classTag = _G.UnitClass("player")
        iconPath = Theme.ClassIcon(classTag)
      end
      if not iconPath then
        iconPath = "Interface\\CHATFRAME\\UI-ChatIcon-ArmoryChat"
      end
    else
      iconPath = Theme.ClassIcon(message.classTag or message.senderClassTag)
      if not iconPath then
        iconPath = Theme.TEXTURES.bnet_icon
      end
    end
    if icon.SetTexture then
      icon:SetTexture(iconPath)
    end
  end

  -- Total height for layout purposes
  local totalHeight = bubbleHeight

  return {
    frame     = frame,
    bgFills   = bgFills,
    bgCorners = bgCorners,
    text      = textFS,
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

---------------------------------------------------------------------------
-- Export
---------------------------------------------------------------------------

ns.ChatBubble = ChatBubble

return ChatBubble
