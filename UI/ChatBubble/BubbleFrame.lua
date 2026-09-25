local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local BubbleStructure = ns.ChatBubbleBubbleStructure or require("WhisperMessenger.UI.ChatBubble.BubbleStructure")
local BubbleIcon = ns.ChatBubbleBubbleIcon or require("WhisperMessenger.UI.ChatBubble.BubbleIcon")
local ContextMenu = ns.ChatBubbleContextMenu or require("WhisperMessenger.UI.ChatBubble.ContextMenu")
local HoverCopy = ns.ChatBubbleHoverCopy or require("WhisperMessenger.UI.ChatBubble.HoverCopy")
local Hyperlinks = ns.UIHyperlinks or require("WhisperMessenger.UI.Hyperlinks")
local MessageReactions = ns.MessageReactions or require("WhisperMessenger.Model.MessageReactions")
local ReactionAssets = ns.ChatBubbleReactionAssets or require("WhisperMessenger.UI.ChatBubble.ReactionAssets")
local ReactionBadge = ns.ChatBubbleReactionBadge or require("WhisperMessenger.UI.ChatBubble.ReactionBadge")
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")
local ReplyQuote = ns.ChatBubbleReplyQuote or require("WhisperMessenger.UI.ChatBubble.ReplyQuote")


local BubbleFrame = {}
local function reactionsAllowed(message, canReact)
  if type(canReact) == "function" then
    return canReact(message)
  end
  return MessageReactions.IsEligible(message)
end

local function applyBubbleColor(frame, colorTable, alphaScale)
  local r, g, b = colorTable[1], colorTable[2], colorTable[3]
  local a = (colorTable[4] or 1) * (alphaScale or 1)
  for _, part in ipairs(frame._bgFills) do
    if part.SetColorTexture then
      part:SetColorTexture(r, g, b, a)
    end
  end
  for _, part in ipairs(frame._bgCorners) do
    if part.SetVertexColor then
      part:SetVertexColor(r, g, b, a)
    end
  end
end

local function revealCensored(frame)
  local message = frame._wmMessage
  if message == nil or message.isCensored ~= true then
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
  if type(frame._wmOnRevealCensored) == "function" then
    frame._wmOnRevealCensored()
  end
end

local function openBubbleMenu(frame)
  local message = frame._wmMessage
  if message == nil then
    return
  end
  local options = frame._wmContextMenuOptions
  if options == nil then
    options = {}
    frame._wmContextMenuOptions = options
  end
  options.message = message
  options.onReact = frame._wmOnReact
  options.canReact = frame._wmCanReact
  options.factory = frame._wmPersistentFactory
  options.onReply = nil
  local onReply, canReply = frame._wmOnReply, frame._wmCanReply
  if type(onReply) == "function" and type(canReply) == "function" and canReply(message) then
    options.onReply = function()
      onReply(message)
    end
  end
  ContextMenu.Open(message.text or "", frame, options)
end

local function bubbleOnMouseDown(self, button)
  if button == "LeftButton" and self._wmMessage and self._wmMessage.isCensored == true then
    revealCensored(self)
    return
  end
  if button ~= "RightButton" then
    return
  end
  self._wmOpenedOnMouseDown = true
  openBubbleMenu(self)
end

local function bubbleOnMouseUp(self, button)
  if button ~= "RightButton" then
    return
  end
  if self._wmOpenedOnMouseDown then
    self._wmOpenedOnMouseDown = false
    return
  end
  openBubbleMenu(self)
end

local function bubbleOnDoubleClick(self, button)
  local message = self._wmMessage
  if button == "LeftButton" and message and reactionsAllowed(message, self._wmCanReact) then
    self._wmOnReact(message, "heart")
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

  -- Button is required for WoW's native OnDoubleClick script.
  local frame = factory.CreateFrame("Button", nil, parent)
  if frame.RegisterForClicks then
    frame:RegisterForClicks("AnyUp", "AnyDown")
  end
  ReactionBadge.Reset(frame)
  frame._wmMessage = message
  frame._wmOnRevealCensored = options.onRevealCensored
  frame._wmOnReact = options.onReact
  frame._wmCanReact = options.canReact
  frame._wmOnReply = options.onReply
  frame._wmCanReply = options.canReply
  frame._wmPersistentFactory = options.persistentFactory or factory
  frame._wmOpenedOnMouseDown = false

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

  local fontColorOverride = Fonts.GetFontColorRGBA and Fonts.GetFontColorRGBA() or nil

  if kind == "system" then
    setFontObject(textFS, Theme.FONTS.system_text)
    setTextColor(textFS, Theme.COLORS.text_system)
    applyBubbleColor(frame, Theme.COLORS.bg_bubble_system)
  elseif kind == "channel_context" then
    -- Channel context: muted version of incoming bubble
    setFontObject(textFS, Theme.FONTS.message_text)
    setTextColor(textFS, fontColorOverride or Theme.COLORS.text_received)
    applyBubbleColor(frame, Theme.COLORS.bg_bubble_in, 0.55)
  elseif direction == "out" then
    setFontObject(textFS, Theme.FONTS.message_text)
    setTextColor(textFS, fontColorOverride or Theme.COLORS.text_sent)
    applyBubbleColor(frame, Theme.COLORS.bg_bubble_out)
  else
    setFontObject(textFS, Theme.FONTS.message_text)
    setTextColor(textFS, fontColorOverride or Theme.COLORS.text_received)
    applyBubbleColor(frame, Theme.COLORS.bg_bubble_in)
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

  local quoteWidth = ReplyQuote.Apply(options.persistentFactory or factory, frame, message, textAvailWidth, pH, pV, options.onQuoteClick)
  local quoteHeight = quoteWidth > 0 and ReplyQuote.HEIGHT or 0
  local bubbleInnerWidth = math.max(textColumnWidth, quoteWidth)
  local bubbleInnerHeight = textHeight + quoteHeight
  local bubbleWidth = bubbleInnerWidth + pH * 2
  local bubbleHeight = bubbleInnerHeight + pV * 2

  textFS:ClearAllPoints()
  textFS:SetWidth(textColumnWidth)
  textFS:SetJustifyH("LEFT")
  textFS:SetText(displayText)
  textFS:SetPoint("TOPLEFT", frame, "TOPLEFT", pH, -pV - quoteHeight)

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

  if kind ~= "system" then
    HoverCopy.Attach(options.persistentFactory or factory, frame, message, options.copyText or ContextMenu.CopyText)
  elseif frame._copyButton and frame._copyButton.Hide then
    frame._copyButton:Hide()
  end

  if frame.SetScript then
    frame:SetScript("OnMouseDown", bubbleOnMouseDown)
    frame:SetScript("OnMouseUp", bubbleOnMouseUp)
    frame:SetScript("OnDoubleClick", nil)
    if type(options.onReact) == "function" and kind == "user" and direction == "in" and message.delivery ~= "blocked" then
      frame:SetScript("OnDoubleClick", bubbleOnDoubleClick)
    end
  end

  frame:SetSize(bubbleWidth, bubbleHeight)

  local icon = nil
  local iconFrame = nil
  if (kind == "user" or kind == "channel_context") and showIcon then
    local iconOptions = frame._wmIconOptions
    if iconOptions == nil then
      iconOptions = {}
      frame._wmIconOptions = iconOptions
    end
    iconOptions.fallbackClassTag = options.fallbackClassTag
    iconOptions.iconFactory = options.iconFactory
    local bubbleIcon = BubbleIcon.CreateIcon(options.iconFactory or factory, parent, frame, message, direction, iconOptions)
    icon = bubbleIcon.texture
    iconFrame = bubbleIcon.frame
  end

  local totalHeight = bubbleHeight
  local reactionFrame
  local reactionIcon
  local reaction = MessageReactions.VisibleReaction(message)
  if kind == "user" and reaction and ReactionAssets.GetTexCoords(reaction.key) then
    reactionFrame, reactionIcon = ReactionBadge.Show(options.persistentFactory or factory, frame, reaction, direction)
    totalHeight = totalHeight + ReactionAssets.GetBadgeOverflow()
  end

  local result = frame._wmBubbleResult
  if result == nil then
    result = {}
    frame._wmBubbleResult = result
  end
  result.frame = frame
  result.iconFrame = iconFrame
  result.bgFills = bgFills
  result.bgCorners = bgCorners
  result.text = textFS
  result.icon = icon
  result.reactionFrame = reactionFrame
  result.reactionIcon = reactionIcon
  result.kind = kind
  result.direction = direction
  result.height = totalHeight
  return result
end

ns.ChatBubbleBubbleFrame = BubbleFrame
return BubbleFrame
