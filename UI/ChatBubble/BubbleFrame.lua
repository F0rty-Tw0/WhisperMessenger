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
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor

local Fonts = ns.ThemeFonts or require("WhisperMessenger.UI.Theme.Fonts")

local BubbleFrame = {}
local function reactionsAllowed(message, canReact)
  if type(canReact) == "function" then
    return canReact(message)
  end
  return MessageReactions.IsEligible(message)
end

local function hideReactionTooltip(frame)
  if frame and frame._reactionTooltipOwned and _G.GameTooltip and type(_G.GameTooltip.Hide) == "function" then
    _G.GameTooltip:Hide()
  end
  if frame then
    frame._reactionTooltipOwned = nil
  end
end

local function resetReactionBadge(frame)
  local reactionFrame = frame._reactionFrame
  if reactionFrame then
    hideReactionTooltip(reactionFrame)
    if reactionFrame.SetScript then
      reactionFrame:SetScript("OnEnter", nil)
      reactionFrame:SetScript("OnLeave", nil)
    end
    if reactionFrame.ClearAllPoints then
      reactionFrame:ClearAllPoints()
    end
    if reactionFrame.Hide then
      reactionFrame:Hide()
    end
  end
  local texture = frame._reactionTexture
  if texture then
    if texture.SetTexture then
      texture:SetTexture(nil)
    end
    if texture.SetTexCoord then
      texture:SetTexCoord(0, 1, 0, 1)
    end
    if texture.Hide then
      texture:Hide()
    end
  end
  frame._reactionKey = nil
end

local function showReactionBadge(factory, frame, reaction, direction)
  local reactionFrame = frame._reactionFrame
  if reactionFrame == nil then
    reactionFrame = factory.CreateFrame("Frame", nil, frame)
    if reactionFrame.EnableMouse then
      reactionFrame:EnableMouse(true)
    end
    frame._reactionFrame = reactionFrame
    local texture = reactionFrame:CreateTexture(nil, "ARTWORK")
    frame._reactionTexture = texture
  end

  local iconSize = ReactionAssets.GetIconSize()
  reactionFrame:SetSize(iconSize, iconSize)
  local texture = frame._reactionTexture
  texture:ClearAllPoints()
  texture:SetPoint("CENTER", reactionFrame, "CENTER", 0, 0)
  texture:SetSize(iconSize, iconSize)
  local coords = ReactionAssets.GetTexCoords(reaction.key)
  texture:SetTexture(ReactionAssets.TEXTURE)
  texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
  if texture.Show then
    texture:Show()
  end

  reactionFrame:ClearAllPoints()
  if direction == "out" then
    reactionFrame:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 5, ReactionAssets.BADGE_OFFSET_Y)
  else
    reactionFrame:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -5, ReactionAssets.BADGE_OFFSET_Y)
  end
  reactionFrame:SetScript("OnEnter", function(self)
    local tooltip = _G.GameTooltip
    if type(tooltip) ~= "table" then
      return
    end
    self._reactionTooltipOwned = true
    if type(tooltip.SetOwner) == "function" then
      tooltip:SetOwner(self, "ANCHOR_TOP")
    end
    if type(tooltip.SetText) == "function" then
      tooltip:SetText(":" .. reaction.key .. ":")
    end
    if type(tooltip.Show) == "function" then
      tooltip:Show()
    end
  end)
  reactionFrame:SetScript("OnLeave", function(self)
    hideReactionTooltip(self)
  end)
  reactionFrame:Show()
  frame._reactionKey = reaction.key
  return reactionFrame, texture
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
  resetReactionBadge(frame)

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
    HoverCopy.Attach(options.persistentFactory or factory, frame, message, copyText)
  end

  if frame.SetScript then
    local openedOnMouseDown = false

    local function openBubbleMenu(anchor)
      local currentText = message.text or ""
      ContextMenu.Open(currentText, anchor or frame, {
        message = message,
        onReact = options.onReact,
        canReact = options.canReact,
        factory = options.persistentFactory or factory,
      })
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
    frame:SetScript("OnDoubleClick", nil)
    if type(options.onReact) == "function" and kind == "user" and direction == "in" and message.delivery ~= "blocked" then
      frame:SetScript("OnDoubleClick", function(_, button)
        if button == "LeftButton" and reactionsAllowed(message, options.canReact) then
          options.onReact(message, "heart")
        end
      end)
    end
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
  local reactionFrame
  local reactionIcon
  local reaction = MessageReactions.VisibleReaction(message)
  if kind == "user" and reaction and ReactionAssets.GetTexCoords(reaction.key) then
    reactionFrame, reactionIcon = showReactionBadge(options.persistentFactory or factory, frame, reaction, direction)
    totalHeight = totalHeight + ReactionAssets.GetBadgeOverflow()
  end

  return {
    frame = frame,
    iconFrame = iconFrame,
    bgFills = bgFills,
    bgCorners = bgCorners,
    text = textFS,
    icon = icon,
    reactionFrame = reactionFrame,
    reactionIcon = reactionIcon,
    kind = kind,
    direction = direction,
    height = totalHeight,
  }
end

ns.ChatBubbleBubbleFrame = BubbleFrame
return BubbleFrame
