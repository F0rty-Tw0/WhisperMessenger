local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local function measureTextHeight(fontString, text, maxWidth)
  fontString:SetWidth(maxWidth)
  fontString:SetText(text or "")
  return fontString:GetStringHeight() or 14
end

local BubbleFrame = {}

function BubbleFrame.CreateBubble(factory, parent, message, options)
  options = options or {}
  local paneWidth = options.paneWidth or 400
  local showIcon = options.showIcon
  local kind = message.kind or "user"
  local direction = message.direction or "in"

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
  if frame.EnableMouse then
    frame:EnableMouse(true)
  end
  if frame.SetHyperlinksEnabled then
    frame:SetHyperlinksEnabled(true)
  end
  if frame.SetScript then
    frame:SetScript("OnHyperlinkEnter", function(self, link, _text)
      if type(_G.GameTooltip) == "table" and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        _G.GameTooltip:SetHyperlink(link)
        _G.GameTooltip:Show()
      end
    end)
    frame:SetScript("OnHyperlinkLeave", function(self)
      if type(_G.GameTooltip) == "table" and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)
    frame:SetScript("OnHyperlinkClick", function(self, link, text, button)
      if type(_G.SetItemRef) == "function" then
        _G.SetItemRef(link, text, button, self)
      end
    end)
  end

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
  local function makeCorner(point, _relPoint)
    local c = frame:CreateTexture(nil, "BACKGROUND")
    c:SetSize(CORNER_R, CORNER_R)
    c:SetPoint(point, frame, point, 0, 0)
    if c.SetTexture then
      c:SetTexture(CIRCLE_TEX)
    end
    return c
  end

  local cTL = makeCorner("TOPLEFT")
  local cTR = makeCorner("TOPRIGHT")
  local cBL = makeCorner("BOTTOMLEFT")
  local cBR = makeCorner("BOTTOMRIGHT")

  -- Set TexCoord to select the correct quarter of the circle
  if cTL.SetTexCoord then
    cTL:SetTexCoord(0, 0.5, 0, 0.5) -- top-left quarter
    cTR:SetTexCoord(0.5, 1, 0, 0.5) -- top-right quarter
    cBL:SetTexCoord(0, 0.5, 0.5, 1) -- bottom-left quarter
    cBR:SetTexCoord(0.5, 1, 0.5, 1) -- bottom-right quarter
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
  local rightMargin = 12
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
  local bubbleInnerWidth = textColumnWidth
  local bubbleInnerHeight = textHeight
  local bubbleWidth = bubbleInnerWidth + pH * 2
  local bubbleHeight = bubbleInnerHeight + pV * 2

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
      iconPath = Theme.ClassIcon(message.classTag or message.senderClassTag or options.fallbackClassTag)
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
    frame = frame,
    bgFills = bgFills,
    bgCorners = bgCorners,
    text = textFS,
    icon = icon,
    kind = kind,
    direction = direction,
    height = totalHeight,
  }
end

ns.ChatBubbleBubbleFrame = BubbleFrame
return BubbleFrame
