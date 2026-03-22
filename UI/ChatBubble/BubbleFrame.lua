local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor
local createCircularIcon = UIHelpers.createCircularIcon

local function measureTextHeight(fontString, text, maxWidth)
  fontString:SetWidth(maxWidth)
  fontString:SetText(text or "")
  return fontString:GetStringHeight() or 14
end

local CORNER_R = 8
local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMaskSmall"

-- Pre-cache the corner texture at load time so it's in memory before any bubble is created
if type(_G.UIParent) == "table" and type(_G.UIParent.CreateTexture) == "function" then
  local preload = _G.UIParent:CreateTexture(nil, "BACKGROUND")
  preload:SetTexture(CIRCLE_TEX)
  preload:SetAlpha(0)
  preload:SetSize(1, 1)
end

local BubbleFrame = {}

-- Create the structural frame elements (textures, corners, font string).
-- Called once per frame; results are cached on frame._bgFills, _bgCorners, _textFS.
local function createBubbleStructure(frame)
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

  local function makeCorner(point)
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

  if cTL.SetTexCoord then
    cTL:SetTexCoord(0, 0.5, 0, 0.5)
    cTR:SetTexCoord(0.5, 1, 0, 0.5)
    cBL:SetTexCoord(0, 0.5, 0.5, 1)
    cBR:SetTexCoord(0.5, 1, 0.5, 1)
  end

  local bgFills = { bgCenter, bgTop, bgBottom, bgLeft, bgRight }
  local bgCorners = { cTL, cTR, cBL, cBR }
  local textFS = frame:CreateFontString(nil, "OVERLAY")

  frame._bgFills = bgFills
  frame._bgCorners = bgCorners
  frame._textFS = textFS

  return bgFills, bgCorners, textFS
end

function BubbleFrame.CreateBubble(factory, parent, message, options)
  options = options or {}
  local paneWidth = options.paneWidth or 400
  local showIcon = options.showIcon
  local kind = message.kind or "user"
  local direction = message.direction or "in"

  local pH = Theme.LAYOUT.BUBBLE_PADDING_H
  local pV = Theme.LAYOUT.BUBBLE_PADDING_V
  local maxBubbleWidth = paneWidth * Theme.LAYOUT.BUBBLE_MAX_WIDTH_PCT

  if kind == "system" then
    pH = 8
    pV = 4
  end

  -- Acquire or create frame
  local frame = factory.CreateFrame("Frame", nil, parent)

  -- Create structure once, reuse on subsequent calls
  local bgFills = frame._bgFills
  local bgCorners = frame._bgCorners
  local textFS = frame._textFS
  if not textFS then
    bgFills, bgCorners, textFS = createBubbleStructure(frame)
  else
    -- Re-show cached regions (hidden during pool release)
    for _, part in ipairs(bgFills) do
      if part.Show then
        part:Show()
      end
    end
    for _, part in ipairs(bgCorners) do
      if part.Show then
        part:Show()
      end
    end
    if textFS.Show then
      textFS:Show()
    end
  end

  local function applyBubbleColor(colorTable)
    local r, g, b, a = colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1
    for _, part in ipairs(bgFills) do
      if part.SetColorTexture then
        part:SetColorTexture(r, g, b, a)
      end
    end
    for _, part in ipairs(bgCorners) do
      if part.SetVertexColor then
        part:SetVertexColor(r, g, b, a)
      end
    end
  end

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

  local iconLeftMargin = 48
  local rightMargin = 12
  local textAvailWidth = maxBubbleWidth - pH * 2

  local textHeight = measureTextHeight(textFS, message.text, textAvailWidth)

  local textColumnWidth = textAvailWidth
  if type(textFS.GetStringWidth) == "function" then
    local rawWidth = textFS:GetStringWidth() or 0
    if rawWidth > 0 then
      textColumnWidth = math.min(rawWidth, textAvailWidth)
    end
  end

  if textColumnWidth < textAvailWidth then
    textHeight = measureTextHeight(textFS, message.text, textColumnWidth)
  end

  local bubbleInnerWidth = textColumnWidth
  local bubbleInnerHeight = textHeight
  local bubbleWidth = bubbleInnerWidth + pH * 2
  local bubbleHeight = bubbleInnerHeight + pV * 2

  textFS:ClearAllPoints()
  textFS:SetWidth(textColumnWidth)
  textFS:SetJustifyH("LEFT")
  textFS:SetText(message.text or "")
  textFS:SetPoint("TOPLEFT", frame, "TOPLEFT", pH, -pV)

  frame:SetSize(bubbleWidth, bubbleHeight)

  if kind == "system" then
    frame:SetPoint("TOP", parent, "TOPLEFT", paneWidth / 2, 0)
  elseif direction == "out" then
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -rightMargin, 0)
  else
    local leftOffset = iconLeftMargin
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", leftOffset, 0)
  end

  local icon = nil
  local iconFrame = nil
  if kind == "user" and showIcon then
    local iconFact = options.iconFactory or factory
    local bubbleIcon = createCircularIcon(iconFact, parent, Theme.LAYOUT.BUBBLE_ICON_SIZE)
    iconFrame = bubbleIcon.frame
    icon = bubbleIcon.texture
    if direction == "in" then
      bubbleIcon.frame:SetPoint("TOPRIGHT", frame, "TOPLEFT", -8, 0)
    else
      bubbleIcon.frame:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, 0)
    end

    local iconPath
    if direction == "out" then
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

  local totalHeight = bubbleHeight

  return {
    frame = frame,
    iconFrame = iconFrame,
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
