local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor

local GLOW_RATIO = 1.8
local PULSE_MIN_SCALE = 0.75
local PULSE_MAX_SCALE = 1.1
local PULSE_FADE_IN = 0.5
local PULSE_FADE_OUT = 1.0
local PULSE_SCALE_SECONDS = 0.75

local PulseGlow = {}

function PulseGlow.Create(factory, frame, options)
  options = options or {}
  local theme = options.theme or Theme
  local accent = options.accent or theme.COLORS.accent
  local iconSize
  if type(frame.GetWidth) == "function" then
    iconSize = frame:GetWidth()
  end
  if type(iconSize) ~= "number" or iconSize <= 0 then
    iconSize = theme.LAYOUT and theme.LAYOUT.ICON_SIZE or 40
  end

  local glowFrame = factory.CreateFrame("Frame", nil, frame)
  glowFrame:SetPoint("CENTER", frame, "CENTER", 0, 0)
  glowFrame:SetSize(iconSize * GLOW_RATIO, iconSize * GLOW_RATIO)
  glowFrame:SetAlpha(0)
  if type(frame.GetFrameLevel) == "function" then
    glowFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
  end

  local glowTexture = glowFrame:CreateTexture(nil, "ARTWORK")
  glowTexture:SetAllPoints(glowFrame)
  glowTexture:SetAtlas("GarrLanding-CircleGlow")
  if glowTexture.SetBlendMode then
    glowTexture:SetBlendMode("ADD")
  end
  applyVertexColor(glowTexture, accent)
  glowFrame:Hide()

  local pulseAnim = nil
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

  local pulseActive = false
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

  local function applyIconSize(newSize)
    newSize = tonumber(newSize) or iconSize
    glowFrame:SetSize(newSize * GLOW_RATIO, newSize * GLOW_RATIO)
  end

  local function applyTheme(activeTheme)
    activeTheme = activeTheme or theme
    if glowTexture and glowTexture.SetVertexColor then
      applyVertexColor(glowTexture, activeTheme.COLORS.accent)
    end
  end

  return {
    glowFrame = glowFrame,
    glowTexture = glowTexture,
    animation = pulseAnim,
    start = startPulse,
    stop = stopPulse,
    applyIconSize = applyIconSize,
    applyTheme = applyTheme,
  }
end

ns.ToggleIconPulseGlow = PulseGlow

return PulseGlow
