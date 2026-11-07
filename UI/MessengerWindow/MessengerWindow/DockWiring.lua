local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Theme = ns.Theme or require("WhisperMessenger.UI.Theme")
local PhoneDock = ns.MessengerWindowPhoneDock or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDock")
local PhoneDockFlow = ns.MessengerWindowPhoneDockFlow or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDockFlow")
local WindowGrowAnimation = ns.MessengerWindowWindowGrowAnimation
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGrowAnimation")

-- The floating button docking on the window's corner while it is open, and
-- the window growing out of its source, in both layouts. Hooks() returns the
-- calls MessengerWindow makes while building, which do nothing until Attach
-- fills them in. With Open at saved spot off, the window opens at the button
-- and the button's home follows every move of the window.
local DockWiring = {}

function DockWiring.Hooks()
  return {
    dock = function() end,
    onWindowMoved = function() end,
    onStrataChanged = function(_strata) end,
    isWindowPart = function(_candidate)
      return false
    end,
  }
end

-- The window's position callback, run after the window moved by hand (drag,
-- resize, rail snap): the button adopts the spot first, then onPositionChanged.
function DockWiring.WrapPosition(hooks, onPositionChanged)
  return function(nextState)
    hooks.onWindowMoved()
    onPositionChanged(nextState)
  end
end

-- parts: hooks (from Hooks()), factory, chrome, windowOptions
-- (MessengerWindow.Create options), windowAlpha, onPositionChanged(state),
-- buildState(window). One call per window.
function DockWiring.Attach(window, parts)
  local hooks = parts.hooks
  local chrome = parts.chrome
  local windowOptions = parts.windowOptions
  local getDockIcon = windowOptions.getDockIcon or function()
    return nil
  end

  local openAnimation = WindowGrowAnimation.Attach(window, {
    factory = parts.factory,
    parent = window:GetParent() or _G.UIParent,
    theme = Theme,
    setAlphaHeld = parts.windowAlpha.setHeld,
    refreshAlpha = function()
      parts.windowAlpha.refreshWindowAlpha(true)
    end,
  })

  local rideHandlers = {
    beginDrag = function()
      window:StartMoving(true)
    end,
    endDrag = function()
      window:StopMovingOrSizing()
      parts.onPositionChanged(parts.buildState(window))
    end,
  }

  local getGrowSource, isGrowAnimationOn = WindowGrowAnimation.Defaults(windowOptions.getGrowSource, windowOptions.isGrowAnimationOn)
  -- Absent counts as on.
  local isOpenAtSavedSpot = windowOptions.isOpenAtSavedSpot or function()
    return true
  end
  local flow = PhoneDockFlow.Attach(window, {
    chrome = chrome,
    getDockIcon = getDockIcon,
    openAnimation = openAnimation,
    rideHandlers = rideHandlers,
    getGrowSource = getGrowSource,
    isGrowAnimationOn = isGrowAnimationOn,
    isOpenAtSavedSpot = isOpenAtSavedSpot,
  })

  -- The clamp reaches over the corner spot, and over nothing when no button
  -- can dock. A window opening for the first time may have no position until
  -- next frame.
  local function clampToSpot()
    if flow.dockedIcon() == nil and getDockIcon() == nil then
      local _, right, _, bottom = window:GetClampRectInsets()
      window:SetClampRectInsets(0, right, 0, bottom)
      return
    end
    if PhoneDock.ClampToSpot(window, flow.spot()) then
      return
    end
    local timer = _G.C_Timer
    if type(timer) == "table" and type(timer.After) == "function" then
      timer.After(0, function()
        PhoneDock.ClampToSpot(window, flow.spot())
      end)
    end
  end

  -- A re-dock follows a new icon size, scale or icon mode; the spot is always the corner.
  hooks.dock = function()
    flow.dock()
    clampToSpot()
  end
  -- The button's current spot becomes its home. A locked icon keeps its home
  -- and the icon saves through its own onPositionChanged (shared widget position).
  hooks.onWindowMoved = function()
    local icon = flow.dockedIcon()
    if not isOpenAtSavedSpot() and icon and icon.isRiding() then
      icon.adoptRidePosition()
    end
  end
  hooks.onStrataChanged = function(strata)
    flow.setStrata(strata)
  end
  hooks.isWindowPart = flow.isWindowPart

  -- Clamp before the flow: the button rides to where the window ends up.
  window:HookScript("OnShow", clampToSpot)
  window:HookScript("OnShow", flow.open)
  window:HookScript("OnShow", flow.syncIconSlot)
  window:HookScript("OnHide", flow.close)
  return hooks
end

ns.MessengerWindowDockWiring = DockWiring

return DockWiring
