local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local captureFramePosition = UIHelpers.captureFramePosition
local applyVertexColor = UIHelpers.applyVertexColor
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

  local background = frame:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints(frame)
  background:SetTexture(CIRCLE_TEX)
  applyVertexColor(background, Theme.COLORS.icon_bg)

  -- Circular border ring
  local border = frame:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
  border:SetTexture("Interface\\COMMON\\RingBorder")
  applyVertexColor(border, { Theme.COLORS.accent[1], Theme.COLORS.accent[2], Theme.COLORS.accent[3], 0.3 })

  -- Chat icon (speech bubble) instead of text label
  local chatIcon = frame:CreateTexture(nil, "ARTWORK")
  chatIcon:SetSize(ICON_SIZE * CHAT_ICON_RATIO, ICON_SIZE * CHAT_ICON_RATIO)
  chatIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)
  chatIcon:SetTexture("Interface\\CHATFRAME\\UI-ChatWhisperIcon")
  applyVertexColor(chatIcon, Theme.COLORS.text_primary)

  local label = chatIcon -- reference kept for return table

  -- Glow pulse for unread messages (CraftScan-style looping animation)
  -- Wrap glow in its own frame so AnimationGroup targets it directly
  local glowFrame = factory.CreateFrame("Frame", nil, frame)
  glowFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
  glowFrame:SetSize(ICON_SIZE * GLOW_RATIO, ICON_SIZE * GLOW_RATIO)
  glowFrame:SetAlpha(0)
  glowFrame:SetFrameLevel(frame:GetFrameLevel())

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

  local getShowUnreadBadge = options.getShowUnreadBadge
  local getBadgePulse = options.getBadgePulse
  local getIconDesaturated = options.getIconDesaturated

  local lastUnreadCount = 0

  -- Store original colors for desaturation restore
  local originalColors = {
    chatIcon = Theme.COLORS.text_primary,
    background = Theme.COLORS.icon_bg,
    border = { Theme.COLORS.accent[1], Theme.COLORS.accent[2], Theme.COLORS.accent[3], 0.3 },
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
      applyVertexColor(background, isDesat and DESAT_BG or Theme.COLORS.icon_bg)
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
    setUnreadCount = setUnreadCount,
    setCompetitiveContent = setCompetitiveContent,
    applyIconSize = applyIconSize,
    refreshDesaturation = refreshDesaturation,
  }
end

ns.ToggleIcon = ToggleIcon
return ToggleIcon
