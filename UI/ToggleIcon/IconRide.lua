local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Carries the floating button onto the compact window and back. The button
-- glides and grows to its spot on the window, then pins there so it follows
-- the window, keeping its badge and click. Home is its normal anchor, scale
-- and level, restored exactly when it returns.
local GlideClock = ns.GlideClock or require("WhisperMessenger.UI.Shared.GlideClock")

local IconRide = {}

local STRATA_TOKENS = { BACKGROUND = true, LOW = true, MEDIUM = true, HIGH = true }

-- One of the four strata the Widget layer setting offers; anything else is HIGH.
function IconRide.ResolveStrata(value)
  if STRATA_TOKENS[value] then
    return value
  end
  return "HIGH"
end

-- Screen-pixel centre of a region; nil when the client has none yet.
local function screenCenter(region)
  if not region.GetCenter then
    return nil
  end
  local x, y = region:GetCenter()
  if x == nil then
    return nil
  end
  local scale = region:GetEffectiveScale()
  return x * scale, y * scale
end

-- options: theme, parent, onLevel(level) (children with fixed levels),
-- isLocked(), onPositionChanged(state).
function IconRide.Create(frame, options)
  local duration = options.theme.LAYOUT.COMPACT_RIDE_SECONDS
  local parent = options.parent
  local onLevel = options.onLevel or function(_level) end
  -- true as the button leaves for the window, false once it has landed home.
  local onRidingChanged = options.onRidingChanged or function(_riding) end

  ---@type table?
  local home = nil
  local riding = false

  local function setLevel(level)
    frame:SetFrameLevel(level)
    onLevel(level)
  end

  local function captureHome()
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    local centerX, centerY = screenCenter(frame)
    home = {
      point = point,
      relativeTo = relativeTo,
      relativePoint = relativePoint,
      x = x,
      y = y,
      scale = frame:GetScale(),
      level = frame:GetFrameLevel(),
      strata = frame:GetFrameStrata(),
      centerX = centerX,
      centerY = centerY,
    }
  end

  -- A strata change can reset the level, so it is set again after.
  local function setStrataKeepingLevel(strata)
    local level = frame:GetFrameLevel()
    frame:SetFrameStrata(strata)
    setLevel(level)
  end

  local function placeAt(screenX, screenY, scale)
    frame:SetScale(scale)
    local effective = frame:GetEffectiveScale()
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", parent, "BOTTOMLEFT", screenX / effective, screenY / effective)
  end

  -- getEnd() is read every tick: the window may still be settling on screen.
  -- onStep(t, p), when given, runs each frame with the linear time and eased
  -- path, ending on (1, 1), so other animations can share this clock.
  -- instant: arrive at once, whatever the frame's visibility.
  local function glide(toScale, getEnd, onArrive, onStep, instant)
    onStep = onStep or function(_t, _p) end
    local fromX, fromY = screenCenter(frame)
    local fromScale = frame:GetScale()
    local endX = getEnd()
    -- A hidden frame never ticks, so a glide would wait until it shows again.
    if instant or fromX == nil or endX == nil or not frame:IsVisible() then
      GlideClock.Stop(frame)
      onArrive()
      onStep(1, 1)
      return
    end
    local function tick(t, p)
      local toX, toY = getEnd()
      if toX then
        placeAt(fromX + (toX - fromX) * p, fromY + (toY - fromY) * p, fromScale + (toScale - fromScale) * p)
      end
      onStep(t, p)
    end
    local function done()
      onArrive()
      onStep(1, 1)
    end
    GlideClock.Run(frame, duration, tick, done)
  end

  -- target: region, relativePoint, x, y, scale, level.
  local function rideTo(target, onStep, instant)
    if home == nil then
      captureHome()
    end
    riding = true
    onRidingChanged(true)
    setLevel(target.level)
    glide(target.scale, function()
      return screenCenter(target.region)
    end, function()
      frame:SetScale(target.scale)
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", target.region, target.relativePoint, target.x, target.y)
    end, onStep, instant)
  end

  local function restoreHome()
    local saved = home
    if saved == nil then
      return
    end
    home = nil
    frame:SetScale(saved.scale)
    frame:ClearAllPoints()
    frame:SetPoint(saved.point, saved.relativeTo, saved.relativePoint, saved.x, saved.y)
    frame:SetFrameStrata(saved.strata)
    setLevel(saved.level)
    onRidingChanged(false)
  end

  local function rideHome(onStep, instant)
    local saved = home
    if not riding or saved == nil then
      return
    end
    riding = false
    glide(saved.scale, function()
      return saved.centerX, saved.centerY
    end, restoreHome, onStep, instant)
  end

  -- The window moved: where the button is now becomes home. Returns the
  -- position to save, in the button's normal size.
  local function adoptHere()
    local screenX, screenY = screenCenter(frame)
    if screenX == nil then
      return nil
    end
    local homeScale = home and home.scale or 1
    local effective = frame:GetEffectiveScale() / frame:GetScale() * homeScale
    local state = { anchorPoint = "CENTER", relativePoint = "BOTTOMLEFT", x = screenX / effective, y = screenY / effective }
    if home then
      home.point, home.relativeTo, home.relativePoint = "CENTER", parent, "BOTTOMLEFT"
      home.x, home.y = state.x, state.y
      home.centerX, home.centerY = screenX, screenY
    end
    return state
  end

  -- A locked icon keeps its home whatever the window does.
  local function adoptRidePosition()
    if options.isLocked and options.isLocked() then
      return
    end
    local nextState = adoptHere()
    if nextState and options.onPositionChanged then
      options.onPositionChanged(nextState)
    end
  end

  -- Home moved elsewhere (a position reset) while riding. Its centre is
  -- unknown until the button is there, so the return is a jump, not a glide.
  local function setHome(state)
    if home == nil then
      return
    end
    home.point, home.relativeTo, home.relativePoint = state.anchorPoint, parent, state.relativePoint
    home.x, home.y = state.x, state.y
    home.centerX, home.centerY = nil, nil
  end

  -- The window changed strata: on it, the button goes where it goes.
  local function setStrata(strata)
    if riding then
      setStrataKeepingLevel(strata)
    end
  end

  -- The Widget layer changed. Away from home (riding, or gliding back) the
  -- button keeps the window's strata and lands on the new one.
  local function setHomeStrata(value)
    local strata = IconRide.ResolveStrata(value)
    if home ~= nil then
      home.strata = strata
    else
      setStrataKeepingLevel(strata)
    end
    return strata
  end

  return {
    rideTo = rideTo,
    setHomeStrata = setHomeStrata,
    rideHome = rideHome,
    setStrata = setStrata,
    adoptHere = adoptHere,
    adoptRidePosition = adoptRidePosition,
    setHome = setHome,
    isRiding = function()
      return riding
    end,
  }
end

ns.ToggleIconIconRide = IconRide

return IconRide
