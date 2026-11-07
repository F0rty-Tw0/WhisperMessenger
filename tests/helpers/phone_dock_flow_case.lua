local PhoneDockFlow = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDockFlow")
local FakeUI = require("tests.helpers.fake_ui")

local PhoneDockFlowCase = {}

local function at(region, x, y)
  rawset(region, "GetCenter", function()
    return x, y
  end)
end

-- A window, a spot on it, and a recording stand-in for the floating button.
function PhoneDockFlowCase.Build(extra)
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  parent:SetSize(1920, 1080)
  local frame = factory.CreateFrame("Frame", "Window", parent)
  frame:SetSize(360, 640)
  rawset(frame, "GetLeft", function()
    return 100
  end)
  rawset(frame, "GetTop", function()
    return 900
  end)
  local slot = factory.CreateFrame("Frame", nil, frame)
  slot:SetSize(84, 84)
  at(slot, 125, 875)
  local fab = factory.CreateFrame("Button", "Fab", parent)
  fab:SetSize(42, 42)
  at(fab, 500, 600)
  local case = { frame = frame, fab = fab, rides = 0, homes = 0, finished = 0, handlers = {}, animation = true, order = {} }
  case.slot, case.savedSpot, case.dockOn = slot, true, true
  case.openStep, case.closeStep = function() end, function() end
  case.icon = {
    frame = fab,
    isRiding = function()
      return case.rides > case.homes
    end,
    rideTo = function(target, onStep, instant)
      case.rides, case.rodeTo, case.step, case.rideInstant = case.rides + 1, target, onStep, instant
      case.order[#case.order + 1] = "ride"
    end,
    rideHome = function(onStep, instant)
      case.homes, case.step, case.homeInstant = case.homes + 1, onStep, instant
    end,
    setRideHandlers = function(handlers)
      case.rideHandlers = handlers
    end,
    setRideStrata = function(strata)
      case.rideStrata = strata
    end,
  }
  local options = {
    chrome = {
      iconSlot = slot,
      setIconSlotOccupied = function(occupied)
        case.occupied = occupied
      end,
    },
    getDockIcon = function()
      return not case.noIcon and case.icon or nil
    end,
    openAnimation = {
      beginOpen = function(iconFrame)
        case.openedFrom = iconFrame
        case.order[#case.order + 1] = "measure"
        return case.openStep
      end,
      play = function(step)
        case.played = step
        case.order[#case.order + 1] = "play"
      end,
      beginClose = function(iconFrame)
        case.closedInto = iconFrame
        return case.closeStep
      end,
      finish = function()
        case.finished = case.finished + 1
      end,
    },
    rideHandlers = case.handlers,
    getGrowSource = function()
      return fab
    end,
    isGrowAnimationOn = function()
      return case.animation
    end,
    isOpenAtSavedSpot = function()
      return case.savedSpot
    end,
  }
  if not (extra and extra.omitDockOption) then
    options.isIconDockOn = function()
      return case.dockOn
    end
  end
  case.flow = PhoneDockFlow.Attach(frame, options)
  return case
end

return PhoneDockFlowCase
