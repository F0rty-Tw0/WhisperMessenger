local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local UIHelpers = ns.UIHelpers or require("WhisperMessenger.UI.Helpers")
local GlideClock = ns.GlideClock or require("WhisperMessenger.UI.Shared.GlideClock")

-- The window (classic or phone) coming out of its icon (the floating button
-- or the minimap icon) and shrinking back into it. Scaling a real window
-- makes its text and hairlines shimmer, so nothing real is scaled: a plain
-- panel grows from the icon to the window's exact size, and the window,
-- already full size and laid out, fades in over it. The phone ride passes its
-- own steps (IconRide's clock keeps button, panel and fade together); `play`
-- runs the steps on the panel's own clock when there is no ride.
local WindowGrowAnimation = {}

-- Fractions of the animation's time.
local REVEAL_START = 0.55
local PANEL_FADE_START = 0.85
-- Under the raised window (level 2000, see WindowStrata), so the window fades
-- in over a solid panel; under the button (PHONE_RIDE_FRAME_LEVEL) too.
local PANEL_LEVEL = 1990
local MIN_PANEL_SIZE = 1
-- Tests find the panel by its level.
WindowGrowAnimation.PANEL_LEVEL = PANEL_LEVEL

local function noSource()
  return nil
end

local function alwaysOn()
  return true
end

-- 0 before start, rising to 1 at t = 1.
local function ramp(t, start)
  if t <= start then
    return 0
  end
  return (t - start) / (1 - start)
end

-- Screen-pixel edges written into `into`, which is returned; nil while the
-- client has no position for the region. Ticks pass a reused table, so a frame
-- of animation makes no garbage.
local function readRect(region, into)
  if not (region.GetLeft and region.GetRight and region.GetTop and region.GetBottom) then
    return nil
  end
  local left, right, top, bottom = region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom()
  if not (left and right and top and bottom) then
    return nil
  end
  local scale = region:GetEffectiveScale()
  into.left, into.right, into.top, into.bottom = left * scale, right * scale, top * scale, bottom * scale
  return into
end

-- The panel grows from a point at the icon's centre, not the icon's square:
-- the icon is round, so the square's corners would show around it. From a
-- point, the panel's corner stays behind the icon all the way to the window's.
local function readCenterPoint(region, into)
  local rect = readRect(region, into)
  if rect == nil then
    return nil
  end
  local x = (rect.left + rect.right) / 2
  local y = (rect.top + rect.bottom) / 2
  rect.left, rect.right, rect.top, rect.bottom = x, x, y, y
  return rect
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
function WindowGrowAnimation.Attach(frame, options)
  local parent = options.parent
  local theme = options.theme
  local duration = theme.LAYOUT.PHONE_RIDE_SECONDS
  local panel, fill, border = buildPanel(options.factory, parent, theme)

  -- Each run owns its steps, so a superseded run's steps do nothing.
  local run = 0
  local opening = false
  local targetAlpha = 1
  -- The moving end of the panel, rewritten each tick. Only one step runs at a
  -- time (a new run makes the old step return at once), so one table is enough.
  local scratch = {}

  -- In the window's strata: a window behind the map closes behind the map.
  local function paint()
    panel:SetFrameStrata(frame:GetFrameStrata())
    panel:SetFrameLevel(PANEL_LEVEL)
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
    panel:SetSize(math.max(MIN_PANEL_SIZE, (right - left) / scale), math.max(MIN_PANEL_SIZE, (top - bottom) / scale))
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
    GlideClock.Stop(panel)
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
    local from = readCenterPoint(iconFrame, {})
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
      placePanel(from, readRect(frame, scratch), p)
      panel:SetAlpha(1 - ramp(t, PANEL_FADE_START))
      frame:SetAlpha(targetAlpha * ramp(t, REVEAL_START))
    end
  end

  -- The window is already hidden; the panel takes its place and shrinks.
  local function beginClose(iconFrame)
    GlideClock.Stop(panel)
    run = run + 1
    local id = run
    releaseWindow()
    local from = readRect(frame, {})
    paint()
    return function(t, p)
      if id ~= run then
        return
      end
      if t >= 1 then
        panel:Hide()
        return
      end
      placePanel(from, readCenterPoint(iconFrame, scratch), p)
      panel:SetAlpha(1 - ramp(t, PANEL_FADE_START))
    end
  end

  -- Runs a begin* step on the panel's own clock. A hidden frame gets no
  -- OnUpdate, so the panel is shown first even if the step cannot place it.
  local function play(step)
    step(0, 0)
    if not panel:IsShown() then
      panel:Show()
    end
    GlideClock.Run(panel, duration, step, function()
      step(1, 1)
    end)
  end

  return {
    ghost = panel,
    beginOpen = beginOpen,
    beginClose = beginClose,
    finish = finish,
    play = play,
  }
end

-- The window's grow options with their defaults: no source, switch on.
function WindowGrowAnimation.Defaults(getSource, isOn)
  return getSource or noSource, isOn or alwaysOn
end

-- A source runs anim's begin (beginOpen or beginClose) on the panel's own
-- clock; none means no animation, and finish() also releases a hold a
-- superseded run left on the window.
function WindowGrowAnimation.GrowFrom(anim, source, begin)
  if source then
    anim.play(begin(source))
    return
  end
  anim.finish()
end

ns.MessengerWindowWindowGrowAnimation = WindowGrowAnimation

return WindowGrowAnimation
