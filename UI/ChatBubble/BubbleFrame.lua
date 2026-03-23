local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local BubbleStructure = ns.ChatBubbleBubbleStructure or require("WhisperMessenger.UI.ChatBubble.BubbleStructure")
local BubbleIcon = ns.ChatBubbleBubbleIcon or require("WhisperMessenger.UI.ChatBubble.BubbleIcon")
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

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
    bgFills, bgCorners, textFS = BubbleStructure.createStructure(frame)
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

  local textHeight = BubbleStructure.measureTextHeight(textFS, message.text, textAvailWidth)

  local textColumnWidth = textAvailWidth
  if type(textFS.GetStringWidth) == "function" then
    local rawWidth = textFS:GetStringWidth() or 0
    if rawWidth > 0 then
      textColumnWidth = math.min(rawWidth, textAvailWidth)
    end
  end

  if textColumnWidth < textAvailWidth then
    textHeight = BubbleStructure.measureTextHeight(textFS, message.text, textColumnWidth)
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
    local bubbleIcon = BubbleIcon.CreateIcon(options.iconFactory or factory, parent, frame, message, direction, {
      fallbackClassTag = options.fallbackClassTag,
      iconFactory = options.iconFactory,
    })
    icon = bubbleIcon.texture
    iconFrame = bubbleIcon.frame
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
