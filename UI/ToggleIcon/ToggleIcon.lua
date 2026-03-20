local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end
local Loader = ns.Loader or require("WhisperMessenger.Core.Loader")
local loadModule = Loader.LoadModule
local Theme = loadModule("WhisperMessenger.UI.Theme", "Theme")
local trace = ns.trace or require("WhisperMessenger.Core.Trace")
local Badge = ns.ToggleIconBadge or require("WhisperMessenger.UI.ToggleIcon.Badge")

local ToggleIcon = {}

function ToggleIcon.Create(factory, options)
  options = options or {}

  local parent = options.parent or _G.UIParent
  local state = options.state or {}
  local anchorPoint = state.anchorPoint or "CENTER"
  local relativePoint = state.relativePoint or anchorPoint
  local x = state.x or 0
  local y = state.y or 0

  local ICON_SIZE = Theme.LAYOUT.ICON_SIZE

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
  local c = Theme.COLORS.icon_bg
  if background.SetVertexColor then
    background:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
  end

  -- Circular border ring
  local border = frame:CreateTexture(nil, "BORDER")
  border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
  border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
  border:SetTexture("Interface\\COMMON\\RingBorder")
  if border.SetVertexColor then
    local bc = Theme.COLORS.accent
    border:SetVertexColor(bc[1], bc[2], bc[3], 0.3)
  end

  -- Chat icon (speech bubble) instead of text label
  local chatIcon = frame:CreateTexture(nil, "ARTWORK")
  chatIcon:SetSize(ICON_SIZE * 0.6, ICON_SIZE * 0.6)
  chatIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)
  chatIcon:SetTexture("Interface\\CHATFRAME\\UI-ChatWhisperIcon")
  if chatIcon.SetVertexColor then
    local tc = Theme.COLORS.text_primary
    chatIcon:SetVertexColor(tc[1], tc[2], tc[3], 1)
  end

  local label = chatIcon -- reference kept for return table

  -- Glow pulse for unread messages (CraftScan-style looping animation)
  -- Wrap glow in its own frame so AnimationGroup targets it directly
  local glowFrame = factory.CreateFrame("Frame", nil, frame)
  glowFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
  glowFrame:SetSize(ICON_SIZE * 1.8, ICON_SIZE * 1.8)
  glowFrame:SetAlpha(0)
  glowFrame:SetFrameLevel(frame:GetFrameLevel())

  local glowTexture = glowFrame:CreateTexture(nil, "ARTWORK")
  glowTexture:SetAllPoints(glowFrame)
  glowTexture:SetAtlas("GarrLanding-CircleGlow")
  if glowTexture.SetBlendMode then
    glowTexture:SetBlendMode("ADD")
  end
  do
    local gc = Theme.COLORS.accent
    if glowTexture.SetVertexColor then
      glowTexture:SetVertexColor(gc[1], gc[2], gc[3], 1)
    end
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
    fadeIn:SetDuration(0.5)
    fadeIn:SetOrder(1)

    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(0.8)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(1.0)
    fadeOut:SetOrder(2)

    -- Breathe scale 0.75→1.1 over the full cycle
    local scaleUp = ag:CreateAnimation("Scale")
    scaleUp:SetScaleFrom(0.75, 0.75)
    scaleUp:SetScaleTo(1.1, 1.1)
    scaleUp:SetDuration(0.75)
    scaleUp:SetOrder(1)

    local scaleDown = ag:CreateAnimation("Scale")
    scaleDown:SetScaleFrom(1.1, 1.1)
    scaleDown:SetScaleTo(0.75, 0.75)
    scaleDown:SetDuration(0.75)
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

  local function setUnreadCount(count)
    innerSetUnreadCount(count)
    local unreadCount = tonumber(count) or 0
    if unreadCount > 0 then
      startPulse()
    else
      stopPulse()
    end
  end

  -- Hover glow effect
  if frame.SetScript then
    frame:SetScript("OnEnter", function()
      if background.SetVertexColor then
        local hc = Theme.COLORS.send_button_hover
        background:SetVertexColor(hc[1], hc[2], hc[3], hc[4] or 1)
      end
      if _G.GameTooltip and _G.GameTooltip.SetOwner then
        _G.GameTooltip:SetOwner(frame, "ANCHOR_BOTTOM")
        local unreadText = ""
        if badge:IsShown() then
          unreadText = " — " .. badgeLabel:GetText() .. " unread"
        end
        _G.GameTooltip:SetText("WhisperMessenger" .. unreadText)
        _G.GameTooltip:Show()
      end
    end)

    frame:SetScript("OnLeave", function()
      if background.SetVertexColor then
        local lc = Theme.COLORS.icon_bg
        background:SetVertexColor(lc[1], lc[2], lc[3], lc[4] or 1)
      end
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
      local point, _, relative, offsetX, offsetY
      if self.GetPoint then
        point, _, relative, offsetX, offsetY = self:GetPoint()
      else
        local savedPoint = self.point or {}
        point, relative, offsetX, offsetY = savedPoint[1], savedPoint[3], savedPoint[4], savedPoint[5]
      end

      local nextState = {
        anchorPoint = point or "CENTER",
        relativePoint = relative or point or "CENTER",
        x = offsetX or 0,
        y = offsetY or 0,
      }

      trace("icon drag stop", nextState.anchorPoint, nextState.x, nextState.y)
      if options.onPositionChanged then
        options.onPositionChanged(nextState)
      end
    end)
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
    setUnreadCount = setUnreadCount,
  }
end

ns.ToggleIcon = ToggleIcon
return ToggleIcon
