local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local PhoneDock = ns.MessengerWindowPhoneDock or require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDock")

local PhoneDockFlow = {}

-- The button riding onto the window as it comes out of it, and home again.
-- options: chrome (iconSlot, setIconSlotOccupied), getDockIcon(),
-- openAnimation (beginOpen, beginClose, finish), rideHandlers (the drag
-- handlers the button carries while docked), getGrowSource() and
-- isGrowAnimationOn() (these last two are read from the grow source task on).
function PhoneDockFlow.Attach(frame, options)
  local chrome = options.chrome
  local getDockIcon = options.getDockIcon
  local openAnimation = options.openAnimation
  local rideHandlers = options.rideHandlers
  -- The button on the window now. getDockIcon stops returning it once the
  -- icon mode leaves the floating button, but it still has to go home.
  local dockedIcon = nil

  -- Docked and still the floating button: the icon mode can take it away.
  local function syncIconSlot()
    chrome.setIconSlotOccupied(dockedIcon ~= nil and getDockIcon() == dockedIcon)
  end

  -- onStep: the opening animation's, when the window is coming out of the button.
  local function attachIcon(icon, onStep)
    dockedIcon = icon
    icon.setRideHandlers(rideHandlers)
    icon.rideTo(PhoneDock.RideTarget(chrome.iconSlot, icon.frame), onStep)
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

  -- The button travels onto the window as the window comes out of it.
  local function open()
    local icon = getDockIcon()
    if not (icon and icon.rideTo) then
      return
    end
    if icon.isRiding() then
      dock()
      return
    end
    PhoneDock.Place(frame, chrome.iconSlot, icon.frame)
    attachIcon(icon, openAnimation.beginOpen(icon.frame))
  end

  -- Not when only the parent hid (Alt+Z): the window is still open.
  local function close()
    if frame:IsShown() then
      return
    end
    local icon = dockedIcon
    dockedIcon = nil
    if icon and icon.isRiding() then
      icon.setRideHandlers(nil)
      icon.rideHome(openAnimation.beginClose(icon.frame))
    end
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
