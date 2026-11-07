local PhoneDockFlow = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.PhoneDockFlow")
local FakeUI = require("tests.helpers.fake_ui")

local function at(region, x, y)
  rawset(region, "GetCenter", function()
    return x, y
  end)
end

-- A window, a spot on it, and a recording stand-in for the floating button.
local function build()
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
  local case = { frame = frame, fab = fab, rides = 0, homes = 0, finished = 0, handlers = {} }
  case.openStep, case.closeStep = function() end, function() end
  case.icon = {
    frame = fab,
    isRiding = function()
      return case.rides > case.homes
    end,
    rideTo = function(target, onStep)
      case.rides, case.rodeTo, case.step = case.rides + 1, target, onStep
    end,
    rideHome = function(onStep)
      case.homes, case.step = case.homes + 1, onStep
    end,
    setRideHandlers = function(handlers)
      case.rideHandlers = handlers
    end,
    setRideStrata = function(strata)
      case.rideStrata = strata
    end,
  }
  case.flow = PhoneDockFlow.Attach(frame, {
    chrome = {
      iconSlot = slot,
      setIconSlotOccupied = function(occupied)
        case.occupied = occupied
      end,
    },
    getDockIcon = function()
      return case.icon
    end,
    openAnimation = {
      beginOpen = function(iconFrame)
        case.openedFrom = iconFrame
        return case.openStep
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
      return true
    end,
  })
  return case
end

return function()
  -- test_open_rides_the_button_onto_the_spot_with_the_opening_step
  do
    local case = build()
    case.flow.open()
    assert(case.rides == 1 and case.rodeTo.region ~= nil, "the button rides the spot")
    assert(case.step == case.openStep and case.openedFrom == case.fab, "the opening grows out of the button")
    assert(case.rideHandlers == case.handlers, "a drag on the button moves the window")
    assert(case.rideStrata == case.frame:GetFrameStrata(), "with the window's strata")
    assert(case.flow.dockedIcon() == case.icon, "remembered for the way home")
  end

  -- test_close_sends_the_docked_button_home_with_the_closing_step
  do
    local case = build()
    case.flow.open()
    case.frame.shown = false
    case.flow.close()
    assert(case.homes == 1 and case.step == case.closeStep and case.closedInto == case.fab, "home, shrinking into it")
    assert(case.rideHandlers == nil, "the button's drag is its own again")
    assert(case.flow.dockedIcon() == nil, "no longer docked")
  end

  -- test_close_is_ignored_while_the_window_is_still_shown
  do
    local case = build()
    case.flow.open()
    case.frame.shown = true -- Alt+Z hid the parent, not the window
    case.flow.close()
    assert(case.homes == 0 and case.flow.dockedIcon() == case.icon, "the button stays on the open window")
  end

  -- test_dock_while_riding_finishes_the_animation_and_rides_again
  do
    local case = build()
    case.flow.open()
    case.flow.dock()
    assert(case.finished == 1 and case.rides == 2 and case.step == nil, "re-docks with no opening to replay")
  end

  -- test_slot_strata_and_window_part_follow_the_docked_button
  do
    local case = build()
    case.flow.open()
    case.flow.syncIconSlot()
    assert(case.occupied == true, "the slot is taken while the button is docked")
    assert(case.flow.isWindowPart(case.fab) == true and case.flow.isWindowPart(case.frame) == false, "only the button")
    case.flow.setStrata("LOW")
    assert(case.rideStrata == "LOW", "the button follows the window's strata")
  end
end
