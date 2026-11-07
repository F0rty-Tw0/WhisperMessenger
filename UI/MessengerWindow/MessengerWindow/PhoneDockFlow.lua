local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PhoneDock = ns.MessengerWindowPhoneDock or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDock")

local PhoneDockFlow = {}

-- The window growing out of its source (the floating button, the minimap
-- icon, or nothing) and shrinking back, with the floating button riding along.
-- options: chrome (iconSlot, setIconSlotOccupied), getDockIcon(),
-- openAnimation (beginOpen, beginClose, finish, play), rideHandlers (the drag
-- handlers the button carries while docked), getGrowSource() (the frame the
-- window grows from, or nil) and isGrowAnimationOn().
function PhoneDockFlow.Attach(frame, options)
  local chrome = options.chrome
  local getDockIcon = options.getDockIcon
  local openAnimation = options.openAnimation
  local rideHandlers = options.rideHandlers
  local getGrowSource = options.getGrowSource
  local isGrowAnimationOn = options.isGrowAnimationOn
  -- The button on the window now. getDockIcon stops returning it once the
  -- icon mode leaves the floating button, but it still has to go home.
  local dockedIcon = nil
  -- Between a show and the hide that closes it. Alt+Z shows the window again
  -- without a hide in between, and that must not replay the grow.
  local isOpen = false
  -- The frame this open grew from: the close shrinks back into it.
  local rememberedSource = nil

  -- Docked and still the floating button: the icon mode can take it away.
  local function syncIconSlot()
    chrome.setIconSlotOccupied(dockedIcon ~= nil and getDockIcon() == dockedIcon)
  end

  -- onStep: the animation's, when the window is coming out of the button.
  -- instant: the button jumps instead of gliding.
  local function attachIcon(icon, onStep, instant)
    dockedIcon = icon
    icon.setRideHandlers(rideHandlers)
    icon.rideTo(PhoneDock.RideTarget(chrome.iconSlot, icon.frame), onStep, instant)
    -- Reopened mid-glide, it may still be down with the window that closed.
    icon.setRideStrata(frame:GetFrameStrata())
  end

  -- Already riding (the scale changed, or Alt+Z brought the UI back): the
  -- button only needs its new spot, with no opening to replay. A button that
  -- appears on an open window (the icon mode changed) docks where it stands.
  local function dock()
    local icon = dockedIcon
    if icon == nil then
      icon = getDockIcon()
      if icon and icon.rideTo and frame:IsShown() then
        attachIcon(icon)
      end
    elseif icon.isRiding() then
      openAnimation.finish()
      icon.rideTo(PhoneDock.RideTarget(chrome.iconSlot, icon.frame))
    end
    syncIconSlot()
  end

  local function growSource()
    return isGrowAnimationOn() and getGrowSource() or nil
  end

  -- A source runs the grow on the panel's own clock; none means no animation,
  -- and finish() also releases a hold a superseded run left on the window.
  local function growFrom(source, begin)
    if source then
      openAnimation.play(begin(source))
    else
      openAnimation.finish()
    end
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
    local source = growSource()
    rememberedSource = source
    local dockable = icon and icon.rideTo
    if dockable and source == icon.frame then
      attachIcon(icon, openAnimation.beginOpen(icon.frame))
      return
    end
    if dockable then
      attachIcon(icon, nil, true)
    end
    growFrom(source, openAnimation.beginOpen)
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
      -- An instant ride never sends its step (1, 1): growFrom's finish() does.
      icon.rideHome(nil, true)
    end
    growFrom(source, openAnimation.beginClose)
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
  }
end

ns.MessengerWindowPhoneDockFlow = PhoneDockFlow

return PhoneDockFlow
