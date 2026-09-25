local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local applyVertexColor = UIHelpers.applyVertexColor

-- White radial texture, transparent centre fading up to the ring's inner
-- edge and back to zero at the rim. Pinned to the host's edges and never
-- scaled, so the glow stays inside the host (no outer halo). Shared by the widget,
-- minimap icon and What's New button.
local INNER_GLOW_TEXTURE = "Interface\\AddOns\\WhisperMessenger\\Media\\inner-glow.png"
local PULSE_FADE_IN = 0.5
local PULSE_PEAK_HOLD = 0.25 -- keeps the original 1.75s cycle (0.75s + 1.0s)
local PULSE_FADE_OUT = 1.0

local PulseGlow = {}

function PulseGlow.Create(factory, frame, options)
  options = options or {}
  local theme = options.theme or Theme
  local accent = options.accent or theme.COLORS.accent
  local glowFrame = factory.CreateFrame("Frame", nil, frame)
  -- Follows the host's size, including hosts sized after Create (title-bar buttons) and widget resizes.
  glowFrame:SetAllPoints(frame)
  glowFrame:SetAlpha(0)
  if type(frame.GetFrameLevel) == "function" then
    glowFrame:SetFrameLevel(frame:GetFrameLevel() + 5)
  end

  local glowTexture = glowFrame:CreateTexture(nil, "ARTWORK")
  glowTexture:SetAllPoints(glowFrame)
  glowTexture:SetTexture(INNER_GLOW_TEXTURE)
  if glowTexture.SetBlendMode then
    glowTexture:SetBlendMode("ADD")
  end
  applyVertexColor(glowTexture, accent)
  glowFrame:Hide()

  local pulseAnim = nil
  if glowFrame.CreateAnimationGroup then
    local ag = glowFrame:CreateAnimationGroup()
    ag:SetLooping("REPEAT")

    -- Fade in 0→0.8 over 0.5s, hold, then fade out 0.8→0 over 1s. Alpha only:
    -- a scale step would push the glow past the host's edge.
    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(0.8)
    fadeIn:SetDuration(PULSE_FADE_IN)
    fadeIn:SetEndDelay(PULSE_PEAK_HOLD)
    fadeIn:SetOrder(1)

    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(0.8)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(PULSE_FADE_OUT)
    fadeOut:SetOrder(2)

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
    applyTheme = applyTheme,
  }
end

ns.ToggleIconPulseGlow = PulseGlow

return PulseGlow
