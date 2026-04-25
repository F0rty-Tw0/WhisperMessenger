local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local BubbleStructure = ns.ChatBubbleBubbleStructure or require("WhisperMessenger.UI.ChatBubble.BubbleStructure")
local BubbleIcon = ns.ChatBubbleBubbleIcon or require("WhisperMessenger.UI.ChatBubble.BubbleIcon")
local ContextMenu = ns.ChatBubbleContextMenu or require("WhisperMessenger.UI.ChatBubble.ContextMenu")
local Hyperlinks = ns.UIHyperlinks or require("WhisperMessenger.UI.Hyperlinks")
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")

local BubbleFrame = {}

local COPY_BUTTON_SIZE = 14
-- Icon floats outside the bubble corner: 5px past the side edge, 3px above
-- the top edge.
local COPY_BUTTON_EDGE_OFFSET = -5
local COPY_BUTTON_TOP_OFFSET = 7
local COPY_BUTTON_DIM_ALPHA = 0.45
local COPY_BUTTON_TEXTURE = "Interface\\Buttons\\UI-GuildButton-PublicNote-Up"

local function isMouseOver(region)
  if region == nil or type(region.IsMouseOver) ~= "function" then
    return false
  end
  local ok, value = pcall(region.IsMouseOver, region)
  if ok then
    return value == true
  end
  return false
end

local function ensureCopyButton(persistentFactory, frame)
  local button = frame._copyButton
  if button then
    return button
  end
  if type(persistentFactory) ~= "table" or type(persistentFactory.CreateFrame) ~= "function" then
    return nil
  end

  -- Must NOT come from the pooled factory: the FramePool reuses arbitrary
  -- frames by ignoring requested frameType and parent, which would hijack a
  -- recycled avatar/label and drop a non-Button (no OnClick) into our slot.
  button = persistentFactory.CreateFrame("Button", nil, frame)
  button._wmCopyButton = true
  button:SetSize(COPY_BUTTON_SIZE, COPY_BUTTON_SIZE)
  if button.SetFrameLevel and frame.GetFrameLevel then
    local lvl = frame:GetFrameLevel() or 1
    button:SetFrameLevel(lvl + 1)
  end
  if button.EnableMouse then
    button:EnableMouse(true)
  end

  local tex = button:CreateTexture(nil, "OVERLAY")
  if tex.SetAllPoints then
    tex:SetAllPoints(button)
  end
  if tex.SetTexture then
    tex:SetTexture(COPY_BUTTON_TEXTURE)
  end
  if tex.SetVertexColor then
    tex:SetVertexColor(1, 1, 1, 1)
  end
  button._copyTexture = tex

  if button.SetAlpha then
    button:SetAlpha(COPY_BUTTON_DIM_ALPHA)
  end
  if button.Hide then
    button:Hide()
  end

  if button.SetScript then
    button:SetScript("OnEnter", function(self)
      if self.SetAlpha then
        self:SetAlpha(1)
      end
      local tip = _G.GameTooltip
      if type(tip) == "table" and type(tip.SetOwner) == "function" and type(tip.SetText) == "function" then
        tip:SetOwner(self, "ANCHOR_TOP")
        tip:SetText("Copy text")
        if type(tip.Show) == "function" then
          tip:Show()
        end
      end
    end)
    button:SetScript("OnLeave", function(self)
      if self.SetAlpha then
        self:SetAlpha(COPY_BUTTON_DIM_ALPHA)
      end
      local tip = _G.GameTooltip
      if type(tip) == "table" and type(tip.Hide) == "function" then
        tip:Hide()
      end
      -- The user moved off the button; if they're not on the bubble either,
      -- hide. Mirrors the bubble's own OnLeave guard so the button doesn't
      -- linger after the cursor has fully left the bubble area.
      if not isMouseOver(frame) then
        self:Hide()
      end
    end)
  end

  frame._copyButton = button
  return button
end

local function attachHoverCopy(persistentFactory, frame, message, copyText)
  local button = ensureCopyButton(persistentFactory, frame)
  if button == nil then
    return
  end
  button:ClearAllPoints()
  if message.direction == "out" then
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", -COPY_BUTTON_EDGE_OFFSET, COPY_BUTTON_TOP_OFFSET)
  else
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", COPY_BUTTON_EDGE_OFFSET, COPY_BUTTON_TOP_OFFSET)
  end
  if button.SetAlpha then
    button:SetAlpha(COPY_BUTTON_DIM_ALPHA)
  end
  if button.Hide then
    button:Hide()
  end

  if button.SetScript then
    button:SetScript("OnClick", function()
      local text = message.text
      if type(text) ~= "string" or text == "" then
        return
      end
      copyText(text)
    end)
  end

  if frame.SetScript then
    frame:SetScript("OnEnter", function()
      if button.Show then
        button:Show()
      end
    end)
    frame:SetScript("OnLeave", function()
      if isMouseOver(button) then
        return
      end
      if button.Hide then
        button:Hide()
      end
    end)
  end
end

function BubbleFrame.CreateBubble(factory, parent, message, options)
  options = options or {}
  local paneWidth = options.paneWidth or 400
  local showIcon = options.showIcon
  local kind = message.kind or "user"
  local direction = message.direction or "in"
  local displayText = Hyperlinks.FormatTextForDisplay(message.text or "")

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

  local fontColorOverride = Fonts.GetFontColorRGBA and Fonts.GetFontColorRGBA() or nil

  if kind == "system" then
    setFontObject(textFS, Theme.FONTS.system_text)
    setTextColor(textFS, Theme.COLORS.text_system)
    applyBubbleColor(Theme.COLORS.bg_bubble_system)
  elseif kind == "channel_context" then
    -- Channel context: muted version of incoming bubble
    setFontObject(textFS, Theme.FONTS.message_text)
    setTextColor(textFS, fontColorOverride or Theme.COLORS.text_received)
    local base = Theme.COLORS.bg_bubble_in
    applyBubbleColor({ base[1], base[2], base[3], (base[4] or 1) * 0.55 })
  elseif direction == "out" then
    setFontObject(textFS, Theme.FONTS.message_text)
    setTextColor(textFS, fontColorOverride or Theme.COLORS.text_sent)
    applyBubbleColor(Theme.COLORS.bg_bubble_out)
  else
    setFontObject(textFS, Theme.FONTS.message_text)
    setTextColor(textFS, fontColorOverride or Theme.COLORS.text_received)
    applyBubbleColor(Theme.COLORS.bg_bubble_in)
  end

  local textAvailWidth = maxBubbleWidth - pH * 2

  local textHeight = BubbleStructure.measureTextHeight(textFS, displayText, textAvailWidth)

  local textColumnWidth = textAvailWidth
  if type(textFS.GetStringWidth) == "function" then
    local rawWidth = textFS:GetStringWidth() or 0
    if rawWidth > 0 then
      textColumnWidth = math.min(rawWidth, textAvailWidth)
    end
  end

  if textColumnWidth < textAvailWidth then
    textHeight = BubbleStructure.measureTextHeight(textFS, displayText, textColumnWidth)
  end

  local bubbleInnerWidth = textColumnWidth
  local bubbleInnerHeight = textHeight
  local bubbleWidth = bubbleInnerWidth + pH * 2
  local bubbleHeight = bubbleInnerHeight + pV * 2

  textFS:ClearAllPoints()
  textFS:SetWidth(textColumnWidth)
  textFS:SetJustifyH("LEFT")
  textFS:SetText(displayText)
  textFS:SetPoint("TOPLEFT", frame, "TOPLEFT", pH, -pV)

  -- Censored message indicator
  local CENSORED_LABEL_HEIGHT = 12
  local censoredLabel = frame._censoredLabel
  if message.isCensored == true then
    if not censoredLabel then
      censoredLabel = frame:CreateFontString(nil, "OVERLAY")
      if censoredLabel.SetWordWrap then
        censoredLabel:SetWordWrap(false)
      end
      frame._censoredLabel = censoredLabel
    end
    setFontObject(censoredLabel, Theme.FONTS.system_text)
    setTextColor(censoredLabel, Theme.COLORS.text_system)
    censoredLabel:SetText("(click to reveal)")
    censoredLabel:ClearAllPoints()
    censoredLabel:SetPoint("TOPLEFT", textFS, "BOTTOMLEFT", 0, -2)
    if censoredLabel.SetAlpha then
      censoredLabel:SetAlpha(0.7)
    end
    if censoredLabel.Show then
      censoredLabel:Show()
    end
    bubbleInnerHeight = bubbleInnerHeight + CENSORED_LABEL_HEIGHT
    bubbleHeight = bubbleInnerHeight + pV * 2
  elseif censoredLabel then
    if censoredLabel.Hide then
      censoredLabel:Hide()
    end
  end

  local function revealCensored()
    if message.isCensored ~= true then
      return
    end
    local chatApi = _G.C_ChatInfo
    if chatApi and message.lineID then
      if type(chatApi.UncensorChatLine) == "function" then
        pcall(chatApi.UncensorChatLine, message.lineID)
      end
      if type(chatApi.GetChatLineText) == "function" then
        local ok, uncensoredText = pcall(chatApi.GetChatLineText, message.lineID)
        if ok and type(uncensoredText) == "string" and uncensoredText ~= "" then
          message.text = uncensoredText
        end
      end
    end
    message.isCensored = nil
    if options.onRevealCensored then
      options.onRevealCensored()
    end
  end

  if kind ~= "system" then
    local copyText = options.copyText or function(text)
      return ContextMenu.CopyText(text)
    end
    attachHoverCopy(options.persistentFactory or factory, frame, message, copyText)
  end

  if frame.SetScript then
    local openedOnMouseDown = false

    local function openBubbleMenu(anchor)
      local currentText = message.text or ""

      ContextMenu.Open(currentText, anchor or frame)
    end

    frame:SetScript("OnMouseDown", function(self, button)
      if button == "LeftButton" and message.isCensored == true then
        revealCensored()
        return
      end

      if button ~= "RightButton" then
        return
      end

      openedOnMouseDown = true
      openBubbleMenu(self)
    end)

    frame:SetScript("OnMouseUp", function(self, button)
      if button ~= "RightButton" then
        return
      end

      if openedOnMouseDown then
        openedOnMouseDown = false
        return
      end

      openBubbleMenu(self)
    end)
  end

  frame:SetSize(bubbleWidth, bubbleHeight)

  local icon = nil
  local iconFrame = nil
  if (kind == "user" or kind == "channel_context") and showIcon then
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
