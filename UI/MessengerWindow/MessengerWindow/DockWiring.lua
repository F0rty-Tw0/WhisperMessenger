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
-- fills them in.
local DockWiring = {}

function DockWiring.Hooks()
  return {
    dock = function() end,
    onStrataChanged = function(_strata) end,
    isWindowPart = function(_candidate)
      return false
    end,
  }
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
      window:StartMoving()
    end,
    endDrag = function()
      window:StopMovingOrSizing()
      parts.onPositionChanged(parts.buildState(window))
    end,
  }

  -- A window opening for the first time may have no position until next frame.
  local function clampToSpot()
    if PhoneDock.ClampToSpot(window, chrome.iconSlot) then
      return
    end
    local timer = _G.C_Timer
    if type(timer) == "table" and type(timer.After) == "function" then
      timer.After(0, function()
        PhoneDock.ClampToSpot(window, chrome.iconSlot)
      end)
    end
  end

  local getGrowSource, isGrowAnimationOn = WindowGrowAnimation.Defaults(windowOptions.getGrowSource, windowOptions.isGrowAnimationOn)
  local flow = PhoneDockFlow.Attach(window, {
    chrome = chrome,
    getDockIcon = getDockIcon,
    openAnimation = openAnimation,
    rideHandlers = rideHandlers,
    getGrowSource = getGrowSource,
    isGrowAnimationOn = isGrowAnimationOn,
  })

  hooks.dock = flow.dock
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
