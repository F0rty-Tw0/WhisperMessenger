local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local CompactDock = ns.MessengerWindowCompactDock or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.CompactDock")
local WindowGrowAnimation = ns.MessengerWindowWindowGrowAnimation
  or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.WindowGrowAnimation")

local CompactDockFlow = {}

-- The window growing out of its source (the floating button, the minimap
-- icon, or nothing) and shrinking back, with the floating button riding along.
-- options: chrome (iconSlot, setIconSlotOccupied), getDockIcon(),
-- openAnimation (beginOpen, beginClose, finish, play), rideHandlers (the drag
-- handlers the button carries while docked), getGrowSource() (the frame the
-- window grows from, or nil), isGrowAnimationOn() (off: the button jumps
-- instead of gliding and the window appears at once) and isOpenAtSavedSpot()
-- (off: the window opens with its icon spot on the button) and
-- isIconDockOn() (off: the button never rides the window and stays where it is;
-- the window still grows from it). A missing isIconDockOn counts as on.
function CompactDockFlow.Attach(frame, options)
  local chrome = options.chrome
  local getDockIcon = options.getDockIcon
  local openAnimation = options.openAnimation
  local rideHandlers = options.rideHandlers
  local getGrowSource = options.getGrowSource
  local isGrowAnimationOn = options.isGrowAnimationOn
  local isOpenAtSavedSpot = options.isOpenAtSavedSpot
  local isIconDockOn = options.isIconDockOn or function()
    return true
  end
  -- The button on the window now. getDockIcon stops returning it once the
  -- icon mode leaves the floating button, but it still has to go home.
  local dockedIcon = nil
  -- Between a show and the hide that closes it. Alt+Z shows the window again
  -- without a hide in between, and that must not replay the grow.
  local isOpen = false
  -- The frame this open grew from: the close shrinks back into it.
  local rememberedSource = nil

  -- The spot of the button on the window, or of the one that would dock next.
  local function currentSpot()
    return chrome.iconSlot
  end

  -- Docked and still the floating button: the icon mode can take it away.
  local function syncIconSlot()
    chrome.setIconSlotOccupied(dockedIcon ~= nil and getDockIcon() == dockedIcon)
  end

  -- onStep: the animation's, when the window is coming out of the button.
  -- instant: the button jumps instead of gliding.
  local function attachIcon(icon, onStep, instant)
    dockedIcon = icon
    icon.setRideHandlers(rideHandlers)
    icon.rideTo(CompactDock.RideTarget(chrome.iconSlot, icon.frame), onStep, instant)
    -- Reopened mid-glide, it may still be down with the window that closed.
    icon.setRideStrata(frame:GetFrameStrata())
  end

  -- Dock button on the window turned off: the button goes home now and the
  -- window takes the not-docked layout.
  local function undock(icon)
    openAnimation.finish()
    icon.setRideHandlers(nil)
    dockedIcon = nil
    if icon.isRiding() then
      icon.rideHome(nil, not isGrowAnimationOn())
    end
  end

  -- Already riding (the scale changed, or Alt+Z brought the UI back): the
  -- button only needs its new spot, with no opening to replay. A button that
  -- appears on an open window (the icon mode or the option changed) docks
  -- where it stands; with the option off, a docked one goes home.
  local function dock()
    local icon = dockedIcon
    if icon ~= nil and not isIconDockOn() then
      undock(icon)
    elseif icon == nil then
      icon = isIconDockOn() and getDockIcon() or nil
      if icon and icon.rideTo and frame:IsShown() then
        attachIcon(icon, nil, not isGrowAnimationOn())
      end
    elseif icon.isRiding() then
      openAnimation.finish()
      icon.rideTo(CompactDock.RideTarget(chrome.iconSlot, icon.frame), nil, not isGrowAnimationOn())
    end
    syncIconSlot()
  end

  local function growSource()
    return isGrowAnimationOn() and getGrowSource() or nil
  end

  -- The window comes out of its source. The button rides onto the window with
  -- the animation's steps when it is the source, and jumps there otherwise.
  local function open()
    if isOpen then
      dock()
      return
    end
    isOpen = true
    local icon = getDockIcon()
    local dockOn = isIconDockOn()
    -- Only a button on screen can take the window to it: without one, or with
    -- docking off, the window opens at its saved spot.
    if dockOn and not isOpenAtSavedSpot() and icon and icon.rideTo and icon.frame:IsVisible() then
      CompactDock.Place(frame, chrome.iconSlot, icon.frame)
    end
    local source = growSource()
    rememberedSource = source
    local dockable = dockOn and icon and icon.rideTo
    if dockable and source == icon.frame then
      attachIcon(icon, openAnimation.beginOpen(icon.frame))
      return
    end
    if dockable then
      attachIcon(icon, nil, true)
    end
    WindowGrowAnimation.GrowFrom(openAnimation, source, openAnimation.beginOpen)
  end

  -- Shrink into the source the window grew from, unless it is gone since.
  local function closeSource()
    local source = rememberedSource
    rememberedSource = nil
    if not isGrowAnimationOn() then
      return nil
    end
    if source and source:IsVisible() then
      return source
    end
    return getGrowSource()
  end

  -- Not when only the parent hid (Alt+Z): the window is still open.
  local function close()
    if frame:IsShown() or not isOpen then
      return
    end
    isOpen = false
    local source = closeSource()
    local icon = dockedIcon
    dockedIcon = nil
    if icon and icon.isRiding() then
      icon.setRideHandlers(nil)
      if source == icon.frame then
        icon.rideHome(openAnimation.beginClose(icon.frame))
        return
      end
      -- An instant ride never sends its step (1, 1): GrowFrom's finish() does.
      icon.rideHome(nil, true)
    end
    WindowGrowAnimation.GrowFrom(openAnimation, source, openAnimation.beginClose)
  end

  -- A press on the docked button closes or drags the window: not a click elsewhere.
  local function isWindowPart(candidate)
    return dockedIcon ~= nil and candidate == dockedIcon.frame
  end

  local function setStrata(strata)
    if dockedIcon then
      dockedIcon.setRideStrata(strata)
    end
  end

  local function currentDockedIcon()
    return dockedIcon
  end

  return {
    open = open,
    close = close,
    dock = dock,
    syncIconSlot = syncIconSlot,
    isWindowPart = isWindowPart,
    setStrata = setStrata,
    dockedIcon = currentDockedIcon,
    spot = currentSpot,
  }
end

ns.MessengerWindowCompactDockFlow = CompactDockFlow

return CompactDockFlow
