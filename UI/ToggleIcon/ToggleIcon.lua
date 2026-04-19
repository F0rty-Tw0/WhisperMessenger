local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local Skins = ns.Skins or require("WhisperMessenger.UI.Theme.Skins")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local captureFramePosition = UIHelpers.captureFramePosition
local applyVertexColor = UIHelpers.applyVertexColor
local createRoundedBackground = UIHelpers.createRoundedBackground
local setFontObject = UIHelpers.setFontObject
local setTextColor = UIHelpers.setTextColor
local trace = ns.trace or require("WhisperMessenger.Core.Trace")
local Badge = ns.ToggleIconBadge or require("WhisperMessenger.UI.ToggleIcon.Badge")
local CompetitiveIndicator = ns.CompetitiveIndicator or require("WhisperMessenger.UI.ToggleIcon.CompetitiveIndicator")

local CHAT_ICON_RATIO = 0.6 -- chat icon scale factor vs ICON_SIZE
local GLOW_RATIO = 1.8 -- glow frame scale factor vs ICON_SIZE
local PULSE_MIN_SCALE = 0.75 -- pulse animation from-scale
local PULSE_MAX_SCALE = 1.1 -- pulse animation to-scale
local PULSE_FADE_IN = 0.5 -- pulse fade-in duration (seconds)
local PULSE_FADE_OUT = 1.0 -- pulse fade-out duration (seconds)
local PULSE_SCALE_SECONDS = 0.75 -- pulse scale animation duration (seconds)
local PREVIEW_GAP = 8
local PREVIEW_MAX_WIDTH = 200
local PREVIEW_MIN_WIDTH = 60
local PREVIEW_HEIGHT = 42
local PREVIEW_CLASS_ICON_SIZE = 18
local PREVIEW_DISMISS_SIZE = 16
local PREVIEW_LEFT_PAD = 6
local PREVIEW_RIGHT_PAD = 6
local PREVIEW_ICON_GAP = 6
local PREVIEW_DISMISS_GAP = 4
local PREVIEW_SENDER_TOP_OFFSET = -8
local PREVIEW_MESSAGE_GAP = -1
local DISMISS_COLOR = { 0.85, 0.15, 0.15, 0.95 }
local DISMISS_COLOR_HOVER = { 1.0, 0.35, 0.35, 1.0 }
local DISMISS_BG_HOVER = { 0.85, 0.15, 0.15, 0.35 }

local PREVIEW_ANCHORS = {
  right = { selfPoint = "LEFT", target = "RIGHT", x = PREVIEW_GAP, y = 0 },
  left = { selfPoint = "RIGHT", target = "LEFT", x = -PREVIEW_GAP, y = 0 },
  top = { selfPoint = "BOTTOM", target = "TOP", x = 0, y = PREVIEW_GAP },
  above = { selfPoint = "BOTTOM", target = "TOP", x = 0, y = PREVIEW_GAP },
  bottom = { selfPoint = "TOP", target = "BOTTOM", x = 0, y = -PREVIEW_GAP },
  below = { selfPoint = "TOP", target = "BOTTOM", x = 0, y = -PREVIEW_GAP },
}

local function resolvePreviewAnchor(position)
  return PREVIEW_ANCHORS[position] or PREVIEW_ANCHORS.right
end

local ToggleIcon = {}

function ToggleIcon.Create(factory, options)
  options = options or {}

  local parent = options.parent or _G.UIParent
  local state = options.state or {}
  local anchorPoint = state.anchorPoint or "CENTER"
  local relativePoint = state.relativePoint or anchorPoint
  local x = state.x or 0
  local y = state.y or 0

  local ICON_SIZE = options.iconSize or Theme.LAYOUT.ICON_SIZE

  local frame = factory.CreateFrame("Button", "WhisperMessengerToggleIcon", parent)
  frame:SetSize(ICON_SIZE, ICON_SIZE)
  frame:SetPoint(anchorPoint, parent, relativePoint, x, y)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")

  -- Circular background: use the circle texture directly, tinted to desired color
  local CIRCLE_TEX = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"

  local function resolveBgColor()
    return Theme.COLORS.toggle_icon_bg or Theme.COLORS.icon_bg
  end
  local function resolveRingColor()
    local c = Theme.COLORS.toggle_icon_ring
    if c then
      return c
    end
    local a = Theme.COLORS.accent or { 1, 1, 1, 1 }
    return { a[1], a[2], a[3], 0.3 }
  end
  local function resolveGlyphColor()
    return Theme.COLORS.toggle_icon_glyph or Theme.COLORS.text_primary
  end
  local function resolveRingTexture()
    local spec = Skins.Get(Skins.GetActive())
    return (spec and spec.toggle_icon_ring_texture) or "Interface\\COMMON\\RingBorder"
  end

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:SetTexture(CIRCLE_TEX)
  applyVertexColor(background, resolveBgColor())

  -- Circular border ring. Texture is skin-driven: Modern presets use the
  -- generic `COMMON\RingBorder` hoop, the Blizzard skin (Azeroth) swaps to
  -- the classic minimap-tracker rune border so the draggable widget reads
  -- as a first-party native element.
  local border = frame:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
  border:SetTexture(resolveRingTexture())
  applyVertexColor(border, resolveRingColor())

  -- Chat icon (speech bubble) instead of text label
  local chatIcon = frame:CreateTexture(nil, "ARTWORK")
  chatIcon:SetSize(ICON_SIZE * CHAT_ICON_RATIO, ICON_SIZE * CHAT_ICON_RATIO)
  chatIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)
  chatIcon:SetTexture("Interface\\CHATFRAME\\UI-ChatWhisperIcon")
  applyVertexColor(chatIcon, resolveGlyphColor())

  local label = chatIcon -- reference kept for return table

  -- Glow pulse for unread messages (CraftScan-style looping animation)
  -- Wrap glow in its own frame so AnimationGroup targets it directly
  local glowFrame = factory.CreateFrame("Frame", nil, frame)
  glowFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
  glowFrame:SetSize(ICON_SIZE * GLOW_RATIO, ICON_SIZE * GLOW_RATIO)
  glowFrame:SetAlpha(0)
  glowFrame:SetFrameLevel(frame:GetFrameLevel() + 5)

  local glowTexture = glowFrame:CreateTexture(nil, "ARTWORK")
  glowTexture:SetAllPoints(glowFrame)
  glowTexture:SetAtlas("GarrLanding-CircleGlow")
  if glowTexture.SetBlendMode then
    glowTexture:SetBlendMode("ADD")
  end
  do
    applyVertexColor(glowTexture, Theme.COLORS.accent)
  end
  glowFrame:Hide()

  local pulseAnim = nil
  local pulseActive = false
  if glowFrame.CreateAnimationGroup then
    local ag = glowFrame:CreateAnimationGroup()
    ag:SetLooping("REPEAT")

    -- Fade in 0→0.8 over 0.5s, then fade out 0.8→0 over 1s
    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(0.8)
    fadeIn:SetDuration(PULSE_FADE_IN)
    fadeIn:SetOrder(1)

    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(0.8)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(PULSE_FADE_OUT)
    fadeOut:SetOrder(2)

    -- Breathe scale PULSE_MIN_SCALE→PULSE_MAX_SCALE over the full cycle
    local scaleUp = ag:CreateAnimation("Scale")
    scaleUp:SetScaleFrom(PULSE_MIN_SCALE, PULSE_MIN_SCALE)
    scaleUp:SetScaleTo(PULSE_MAX_SCALE, PULSE_MAX_SCALE)
    scaleUp:SetDuration(PULSE_SCALE_SECONDS)
    scaleUp:SetOrder(1)

    local scaleDown = ag:CreateAnimation("Scale")
    scaleDown:SetScaleFrom(PULSE_MAX_SCALE, PULSE_MAX_SCALE)
    scaleDown:SetScaleTo(PULSE_MIN_SCALE, PULSE_MIN_SCALE)
    scaleDown:SetDuration(PULSE_SCALE_SECONDS)
    scaleDown:SetOrder(2)

    if ag.SetScript then
      ag:SetScript("OnPlay", function()
        glowFrame:Show()
        glowFrame:SetAlpha(0)
      end)
      ag:SetScript("OnStop", function()
        glowFrame:SetAlpha(0)
        glowFrame:Hide()
      end)
    end

    pulseAnim = ag
  end

  local function startPulse()
    if pulseAnim and not pulseActive then
      pulseActive = true
      pulseAnim:Play()
    end
  end

  local function stopPulse()
    if pulseAnim and pulseActive then
      pulseActive = false
      pulseAnim:Stop()
    end
  end

  -- Unread badge via Badge submodule
  local badgeResult = Badge.Create(factory, frame)
  local badge = badgeResult.badge
  local badgeBackground = badgeResult.badgeBackground
  local badgeLabel = badgeResult.badgeLabel
  local innerSetUnreadCount = badgeResult.setUnreadCount

  -- Competitive content indicator via CompetitiveIndicator submodule
  local competitiveResult = CompetitiveIndicator.Create(factory, frame)
  local competitiveFrame = competitiveResult.frame
  local innerSetCompetitiveActive = competitiveResult.setActive
  local isCompetitiveActive = false

  local function setCompetitiveContent(active)
    isCompetitiveActive = active == true
    innerSetCompetitiveActive(isCompetitiveActive)
  end

  local previewFrame = factory.CreateFrame("Frame", nil, frame)
  previewFrame:SetSize(PREVIEW_MAX_WIDTH, PREVIEW_HEIGHT)
  local currentPreviewPosition = "right"
  local function applyPreviewPosition(position)
    local nextPosition = (type(position) == "string" and position ~= "") and position or "right"
    currentPreviewPosition = nextPosition
    local anchor = resolvePreviewAnchor(nextPosition)
    if previewFrame.ClearAllPoints then
      previewFrame:ClearAllPoints()
    end
    if previewFrame.SetPoint then
      previewFrame:SetPoint(anchor.selfPoint, frame, anchor.target, anchor.x, anchor.y)
    end
  end
  local function resolvePreviewPosition()
    if type(options.getPreviewPosition) == "function" then
      local ok, value = pcall(options.getPreviewPosition)
      if ok and type(value) == "string" and value ~= "" then
        return value
      end
    end
    return currentPreviewPosition
  end
  applyPreviewPosition(resolvePreviewPosition())
  if previewFrame.SetFrameLevel then
    previewFrame:SetFrameLevel(frame:GetFrameLevel() + 1)
  end
  if previewFrame.EnableMouse then
    previewFrame:EnableMouse(true)
  end
  local previewBackground = createRoundedBackground(previewFrame, 4)

  local previewClassIconResult = UIHelpers.createCircularIcon(factory, previewFrame, PREVIEW_CLASS_ICON_SIZE)
  local previewClassIconFrame = previewClassIconResult.frame
  local previewClassIcon = previewClassIconResult.texture
  previewClassIconFrame:SetPoint("LEFT", previewFrame, "LEFT", PREVIEW_LEFT_PAD, 0)
  previewClassIconFrame:Hide()

  local previewDismissButton = factory.CreateFrame("Button", nil, previewFrame)
  previewDismissButton:SetSize(PREVIEW_DISMISS_SIZE, PREVIEW_DISMISS_SIZE)
  previewDismissButton:SetPoint("TOPRIGHT", previewFrame, "TOPRIGHT", 0, 0)
  if previewDismissButton.EnableMouse then
    previewDismissButton:EnableMouse(true)
  end
  local previewDismissBg = previewDismissButton:CreateTexture(nil, "BACKGROUND")
  previewDismissBg:SetAllPoints(previewDismissButton)
  applyVertexColor(previewDismissBg, { 0, 0, 0, 0 })
  local previewDismissLabel = previewDismissButton:CreateFontString(nil, "OVERLAY")
  setFontObject(previewDismissLabel, Theme.FONTS.header_name or Theme.FONTS.contact_name)
  previewDismissLabel:SetPoint("CENTER", previewDismissButton, "CENTER", 0, 0)
  previewDismissLabel:SetText("×")
  setTextColor(previewDismissLabel, DISMISS_COLOR)

  local senderLeft = PREVIEW_LEFT_PAD + PREVIEW_CLASS_ICON_SIZE + PREVIEW_ICON_GAP
  local previewSenderLabel = previewFrame:CreateFontString(nil, "OVERLAY")
  -- Font objects only: a raw SetFont on a FontString overrides the engine's
  -- Unicode glyph-fallback chain and blanks Cyrillic/Greek characters.
  setFontObject(previewSenderLabel, Theme.FONTS.message_text)
  previewSenderLabel:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", senderLeft, PREVIEW_SENDER_TOP_OFFSET)
  previewSenderLabel:SetJustifyH("LEFT")
  previewSenderLabel:SetWordWrap(false)
  if previewSenderLabel.SetMaxLines then
    previewSenderLabel:SetMaxLines(1)
  end

  local previewMessageLabel = previewFrame:CreateFontString(nil, "OVERLAY")
  setFontObject(previewMessageLabel, Theme.FONTS.system_text)
  previewMessageLabel:SetPoint("TOPLEFT", previewSenderLabel, "BOTTOMLEFT", 0, PREVIEW_MESSAGE_GAP)
  previewMessageLabel:SetJustifyH("LEFT")
  previewMessageLabel:SetWordWrap(false)
  if previewMessageLabel.SetMaxLines then
    previewMessageLabel:SetMaxLines(1)
  end
  previewFrame:Hide()

  local function stringWidthOf(fontString)
    if fontString and fontString.GetStringWidth then
      local ok, width = pcall(fontString.GetStringWidth, fontString)
      if ok and type(width) == "number" then
        return width
      end
    end
    return 0
  end

  local function resizePreviewToContent()
    local textLeft = PREVIEW_LEFT_PAD + PREVIEW_CLASS_ICON_SIZE + PREVIEW_ICON_GAP
    local maxMessageBudget = PREVIEW_MAX_WIDTH - textLeft - PREVIEW_RIGHT_PAD
    local maxSenderBudget = maxMessageBudget - PREVIEW_DISMISS_GAP - PREVIEW_DISMISS_SIZE

    if previewSenderLabel.SetWidth then
      previewSenderLabel:SetWidth(maxSenderBudget)
    end
    if previewMessageLabel.SetWidth then
      previewMessageLabel:SetWidth(maxMessageBudget)
    end

    local senderWidth = stringWidthOf(previewSenderLabel)
    local messageWidth = stringWidthOf(previewMessageLabel)
    if senderWidth > maxSenderBudget then
      senderWidth = maxSenderBudget
    end
    if messageWidth > maxMessageBudget then
      messageWidth = maxMessageBudget
    end

    local senderFootprint = senderWidth + PREVIEW_DISMISS_GAP + PREVIEW_DISMISS_SIZE
    local contentWidth = senderFootprint > messageWidth and senderFootprint or messageWidth
    local total = textLeft + contentWidth + PREVIEW_RIGHT_PAD
    if total < PREVIEW_MIN_WIDTH then
      total = PREVIEW_MIN_WIDTH
    elseif total > PREVIEW_MAX_WIDTH then
      total = PREVIEW_MAX_WIDTH
    end
    previewFrame:SetWidth(total)
  end

  local autoDismissGeneration = 0
  local lastPreviewSenderName = nil
  local lastPreviewMessageText = nil
  local lastPreviewClassTag = nil

  local function cancelAutoDismiss()
    autoDismissGeneration = autoDismissGeneration + 1
  end

  local function clearIncomingPreview()
    cancelAutoDismiss()
    lastPreviewSenderName = nil
    lastPreviewMessageText = nil
    lastPreviewClassTag = nil
    previewSenderLabel:SetText("")
    previewMessageLabel:SetText("")
    previewClassIcon:SetTexture(nil)
    previewClassIconFrame:Hide()
    previewFrame:Hide()
  end

  local function triggerDismiss()
    clearIncomingPreview()
    if options.onDismissPreview then
      options.onDismissPreview()
    end
  end

  local function scheduleAutoDismiss()
    cancelAutoDismiss()
    local getter = options.getPreviewAutoDismissSeconds
    local seconds = (type(getter) == "function") and tonumber(getter()) or 0
    if not seconds or seconds <= 0 then
      return
    end
    local cTimer = _G.C_Timer
    if type(cTimer) ~= "table" or type(cTimer.NewTimer) ~= "function" then
      return
    end
    local scheduledGeneration = autoDismissGeneration
    cTimer.NewTimer(seconds, function()
      if scheduledGeneration ~= autoDismissGeneration then
        return
      end
      if previewFrame.IsShown and not previewFrame:IsShown() then
        return
      end
      triggerDismiss()
    end)
  end

  if previewDismissButton.SetScript then
    previewDismissButton:SetScript("OnClick", triggerDismiss)
    previewDismissButton:SetScript("OnEnter", function()
      setTextColor(previewDismissLabel, DISMISS_COLOR_HOVER)
      applyVertexColor(previewDismissBg, DISMISS_BG_HOVER)
    end)
    previewDismissButton:SetScript("OnLeave", function()
      setTextColor(previewDismissLabel, DISMISS_COLOR)
      applyVertexColor(previewDismissBg, { 0, 0, 0, 0 })
    end)
  end

  if previewFrame.SetScript then
    previewFrame:SetScript("OnMouseUp", function(_self, button)
      if button == "RightButton" then
        triggerDismiss()
      end
    end)
  end

  local function setIncomingPreview(senderName, messageText, classTag)
    local hasMessage = type(messageText) == "string" and messageText ~= ""
    if not hasMessage then
      clearIncomingPreview()
      return
    end

    local isSameContent = senderName == lastPreviewSenderName
      and messageText == lastPreviewMessageText
      and classTag == lastPreviewClassTag

    previewSenderLabel:SetText(type(senderName) == "string" and senderName or "")
    previewMessageLabel:SetText(messageText)

    local classIconPath = Theme.ClassIcon(classTag)
    if classIconPath then
      previewClassIcon:SetTexture(classIconPath)
    else
      previewClassIcon:SetTexture(Theme.TEXTURES.bnet_icon)
    end
    previewClassIconFrame:Show()

    applyPreviewPosition(resolvePreviewPosition())
    previewFrame:Show()
    resizePreviewToContent()

    if not isSameContent then
      lastPreviewSenderName = senderName
      lastPreviewMessageText = messageText
      lastPreviewClassTag = classTag
      scheduleAutoDismiss()
    end
  end

  local getShowUnreadBadge = options.getShowUnreadBadge
  local getBadgePulse = options.getBadgePulse
  local getIconDesaturated = options.getIconDesaturated

  local lastUnreadCount = 0

  -- Store original colors for desaturation restore. Re-read on every
  -- theme refresh so preset switches propagate through the desaturate path.
  local originalColors = {
    chatIcon = resolveGlyphColor(),
    background = resolveBgColor(),
    border = resolveRingColor(),
  }
  local DESAT_GREY = { 0.45, 0.45, 0.45, 0.6 }
  local DESAT_BG = { 0.25, 0.25, 0.25, 0.7 }

  local function updateDesaturation(unreadCount)
    local desaturateEnabled = getIconDesaturated and getIconDesaturated()
    local shouldDesaturate = desaturateEnabled and unreadCount == 0

    for _, tex in ipairs({ chatIcon, background, border }) do
      if tex.SetDesaturated then
        tex:SetDesaturated(shouldDesaturate)
      end
    end

    if shouldDesaturate then
      applyVertexColor(chatIcon, DESAT_GREY)
      applyVertexColor(background, DESAT_BG)
      applyVertexColor(border, DESAT_GREY)
    else
      applyVertexColor(chatIcon, originalColors.chatIcon)
      applyVertexColor(background, originalColors.background)
      applyVertexColor(border, originalColors.border)
    end
  end

  local function setUnreadCount(count)
    local showBadge = not getShowUnreadBadge or getShowUnreadBadge()
    local allowPulse = not getBadgePulse or getBadgePulse()
    local unreadCount = tonumber(count) or 0
    lastUnreadCount = unreadCount

    if showBadge then
      innerSetUnreadCount(count)
    else
      innerSetUnreadCount(0)
    end

    if unreadCount > 0 and allowPulse and showBadge then
      startPulse()
    else
      stopPulse()
    end

    updateDesaturation(unreadCount)
  end

  -- Hover glow effect
  if frame.SetScript then
    frame:SetScript("OnEnter", function()
      local isDesat = getIconDesaturated and getIconDesaturated() and lastUnreadCount == 0
      if not isDesat then
        applyVertexColor(background, Theme.COLORS.send_button_hover)
      end
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
        local unreadText = ""
        if badge:IsShown() then
          unreadText = " — " .. badgeLabel:GetText() .. " unread"
        end
        local competitiveText = ""
        if isCompetitiveActive then
          competitiveText = "\nChat unavailable — in competitive content"
        end
        _G.GameTooltip:SetText("WhisperMessenger" .. unreadText .. competitiveText)
        _G.GameTooltip:Show()
      end
    end)

    frame:SetScript("OnLeave", function()
      local isDesat = getIconDesaturated and getIconDesaturated() and lastUnreadCount == 0
      applyVertexColor(background, isDesat and DESAT_BG or resolveBgColor())
      if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
      end
    end)

    frame:SetScript("OnClick", function()
      trace("icon click")
      if options.onToggle then
        options.onToggle()
      end
    end)

    frame:SetScript("OnDragStart", function(self)
      if self.IsMovable == nil or self:IsMovable() then
        self:StartMoving()
        trace("icon drag start")
      end
    end)

    frame:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local nextState = captureFramePosition(self)

      trace("icon drag stop", nextState.anchorPoint, nextState.x, nextState.y)
      if options.onPositionChanged then
        options.onPositionChanged(nextState)
      end
    end)
  end

  local function refreshDesaturation()
    updateDesaturation(lastUnreadCount)
  end

  local function refreshTheme()
    border:SetTexture(resolveRingTexture())
    originalColors.chatIcon = resolveGlyphColor()
    originalColors.background = resolveBgColor()
    originalColors.border = resolveRingColor()
    if glowTexture and glowTexture.SetVertexColor then
      applyVertexColor(glowTexture, Theme.COLORS.accent)
    end
    if previewBackground and previewBackground.setColor then
      previewBackground.setColor(Theme.COLORS.bg_secondary or Theme.COLORS.bg_primary)
    end
    setTextColor(previewSenderLabel, Theme.COLORS.text_primary)
    setTextColor(previewMessageLabel, Theme.COLORS.text_secondary)
    setTextColor(previewDismissLabel, DISMISS_COLOR)
    refreshDesaturation()
  end

  local function applyIconSize(newSize)
    newSize = tonumber(newSize) or ICON_SIZE
    frame:SetSize(newSize, newSize)
    chatIcon:SetSize(math.floor(newSize * CHAT_ICON_RATIO), math.floor(newSize * CHAT_ICON_RATIO))
    glowFrame:SetSize(newSize * GLOW_RATIO, newSize * GLOW_RATIO)
    if border.SetPoint and border.ClearAllPoints then
      border:ClearAllPoints()
      border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
      border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    end
  end

  setUnreadCount(options.unreadCount)
  setIncomingPreview(options.previewSenderName, options.previewMessageText, options.previewClassTag)
  refreshTheme()

  trace("icon created", anchorPoint, x, y)

  return {
    frame = frame,
    background = background,
    border = border,
    label = label,
    badge = badge,
    badgeBackground = badgeBackground,
    badgeLabel = badgeLabel,
    competitiveIndicator = competitiveFrame,
    previewFrame = previewFrame,
    previewSenderLabel = previewSenderLabel,
    previewMessageLabel = previewMessageLabel,
    previewDismissButton = previewDismissButton,
    previewDismissLabel = previewDismissLabel,
    previewClassIcon = previewClassIcon,
    previewClassIconFrame = previewClassIconFrame,
    setUnreadCount = setUnreadCount,
    setCompetitiveContent = setCompetitiveContent,
    setIncomingPreview = setIncomingPreview,
    applyPreviewPosition = applyPreviewPosition,
    applyIconSize = applyIconSize,
    refreshDesaturation = refreshDesaturation,
    refreshTheme = refreshTheme,
  }
end

ns.ToggleIcon = ToggleIcon
return ToggleIcon
