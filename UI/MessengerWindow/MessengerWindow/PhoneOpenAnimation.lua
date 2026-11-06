local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")

-- The phone window coming out of the floating button. Scaling a real window
-- makes its text and hairlines shimmer, so nothing real is scaled: a plain
-- panel grows from the button to the window's exact size, and the window,
-- already full size and laid out, fades in over it. IconRide's clock drives
-- every step, so the button, panel and fade can never drift apart.
local PhoneOpenAnimation = {}

-- Fractions of the animation's time.
local REVEAL_START = 0.55
local PANEL_FADE_START = 0.85
-- Under the raised window (level 2000, see WindowStrata), so the window fades
-- in over a solid panel; under the button (PHONE_RIDE_FRAME_LEVEL) too.
local PANEL_LEVEL = 1990

-- 0 before start, rising to 1 at t = 1.
local function ramp(t, start)
  if t <= start then
    return 0
  end
  return (t - start) / (1 - start)
end

-- Screen-pixel edges; nil while the client has no position for the region.
local function rectOf(region)
  if not (region.GetLeft and region.GetRight and region.GetTop and region.GetBottom) then
    return nil
  end
  local left, right, top, bottom = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
  if not (left and right and top and bottom) then
    return nil
  end
  local scale = region:GetEffectiveScale()
  return { left = left * scale, right = right * scale, top = top * scale, bottom = bottom * scale }
end

local function buildPanel(factory, parent, theme)
  local panel = factory.CreateFrame("Frame", nil, parent)
  panel:SetFrameStrata("HIGH")
  panel:SetFrameLevel(PANEL_LEVEL)
  panel:Hide()
  local fill = panel:CreateTexture(nil, "BACKGROUND")
  fill:SetAllPoints(panel)
  local border = UIHelpers.createBorderBox(panel, theme.COLORS.divider, 1, "BORDER")
  return panel, fill, border
end

-- options: factory, parent, theme, setAlphaHeld(held), refreshAlpha().
function PhoneOpenAnimation.Attach(frame, options)
  local parent = options.parent
  local theme = options.theme
  local panel, fill, border = buildPanel(options.factory, parent, theme)

  -- Each run owns its steps, so a superseded run's steps do nothing.
  local run = 0
  local opening = false
  local targetAlpha = 1

  local function paint()
    UIHelpers.applyColorTexture(fill, theme.COLORS.bg_primary)
    for _, edge in pairs(border or {}) do
      UIHelpers.applyColorTexture(edge, theme.COLORS.divider)
    end
    panel:SetAlpha(1)
  end

  local function placePanel(from, to, p)
    if not (from and to) then
      return
    end
    local scale = panel:GetEffectiveScale()
    local left = from.left + (to.left - from.left) * p
    local right = from.right + (to.right - from.right) * p
    local top = from.top + (to.top - from.top) * p
    local bottom = from.bottom + (to.bottom - from.bottom) * p
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", left / scale, top / scale)
    panel:SetSize((right - left) / scale, (top - bottom) / scale)
    if not panel:IsShown() then
      panel:Show()
    end
  end

  local function releaseWindow()
    if not opening then
      return false
    end
    opening = false
    frame:SetAlpha(targetAlpha)
    options.setAlphaHeld(false)
    return true
  end

  local function finish()
    run = run + 1
    panel:Hide()
    if releaseWindow() then
      options.refreshAlpha()
    end
  end

  -- Returns the step(t, p) for IconRide: t is linear time, p the eased path.
  local function beginOpen(iconFrame)
    finish()
    local id = run
    local from = rectOf(iconFrame)
    targetAlpha = frame:GetAlpha()
    opening = true
    options.setAlphaHeld(true)
    frame:SetAlpha(0)
    paint()
    return function(t, p)
      if id ~= run then
        return
      end
      if t >= 1 then
        finish()
        return
      end
      placePanel(from, rectOf(frame), p)
      panel:SetAlpha(1 - ramp(t, PANEL_FADE_START))
      frame:SetAlpha(targetAlpha * ramp(t, REVEAL_START))
    end
  end

  -- The window is already hidden; the panel takes its place and shrinks.
  local function beginClose(iconFrame)
    run = run + 1
    local id = run
    releaseWindow()
    local from = rectOf(frame)
    paint()
    return function(t, p)
      if id ~= run then
        return
      end
      if t >= 1 then
        panel:Hide()
        return
      end
      placePanel(from, rectOf(iconFrame), p)
      panel:SetAlpha(1 - ramp(t, PANEL_FADE_START))
    end
  end

  return {
    ghost = panel,
    beginOpen = beginOpen,
    beginClose = beginClose,
    finish = finish,
  }
end

ns.MessengerWindowPhoneOpenAnimation = PhoneOpenAnimation

return PhoneOpenAnimation
