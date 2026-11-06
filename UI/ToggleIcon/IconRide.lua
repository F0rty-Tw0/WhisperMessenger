local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- Carries the floating button onto the phone window and back. The button
-- glides and grows to its spot on the window, then pins there so it follows
-- the window, keeping its badge and click. Home is its normal anchor, scale
-- and level, restored exactly when it returns.
local IconRide = {}

-- Longest step the clock takes in one frame. Opening the window does its
-- heavy refresh just as the glide starts; a slow frame then pauses the glide
-- instead of skipping most of it.
local MAX_STEP = 1 / 30

local function easeOut(t)
  local inverse = 1 - t
  return 1 - inverse * inverse * inverse
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
  local duration = options.theme.LAYOUT.PHONE_RIDE_SECONDS
  local parent = options.parent
  local onLevel = options.onLevel or function(_level) end

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
      centerX = centerX,
      centerY = centerY,
    }
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
  local function glide(toScale, getEnd, onArrive, onStep)
    onStep = onStep or function(_t, _p) end
    local fromX, fromY = screenCenter(frame)
    local fromScale = frame:GetScale()
    local endX = getEnd()
    if fromX == nil or endX == nil then
      frame:SetScript("OnUpdate", nil)
      onArrive()
      onStep(1, 1)
      return
    end
    local elapsed = 0
    frame:SetScript("OnUpdate", function(_self, delta)
      elapsed = elapsed + math.min(delta, MAX_STEP)
      if elapsed >= duration then
        frame:SetScript("OnUpdate", nil)
        onArrive()
        onStep(1, 1)
        return
      end
      local t = elapsed / duration
      local p = easeOut(t)
      local toX, toY = getEnd()
      if toX then
        placeAt(fromX + (toX - fromX) * p, fromY + (toY - fromY) * p, fromScale + (toScale - fromScale) * p)
      end
      onStep(t, p)
    end)
  end

  -- target: region, relativePoint, x, y, scale, level.
  local function rideTo(target, onStep)
    if home == nil then
      captureHome()
    end
    riding = true
    setLevel(target.level)
    glide(target.scale, function()
      return screenCenter(target.region)
    end, function()
      frame:SetScale(target.scale)
      frame:ClearAllPoints()
      frame:SetPoint("CENTER", target.region, target.relativePoint, target.x, target.y)
    end, onStep)
  end

  local function restoreHome()
    local saved = home
    home = nil
    frame:SetScale(saved.scale)
    frame:ClearAllPoints()
    frame:SetPoint(saved.point, saved.relativeTo, saved.relativePoint, saved.x, saved.y)
    setLevel(saved.level)
  end

  local function rideHome(onStep)
    if not riding then
      return
    end
    riding = false
    glide(home.scale, function()
      return home.centerX, home.centerY
    end, restoreHome, onStep)
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

  return {
    rideTo = rideTo,
    rideHome = rideHome,
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
