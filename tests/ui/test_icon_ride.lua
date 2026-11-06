local IconRide = require("WhisperMessenger.UI.ToggleIcon.IconRide")
local Theme = require("WhisperMessenger.UI.Theme")
local FakeUI = require("tests.helpers.fake_ui")

local SECONDS = Theme.LAYOUT.PHONE_RIDE_SECONDS

local function build()
  local factory = FakeUI.NewFactory()
  local parent = factory.CreateFrame("Frame", "UIParent", nil)
  local frame = factory.CreateFrame("Button", "Fab", parent)
  frame:SetSize(42, 42)
  frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 40)
  frame:SetFrameLevel(5)
  local case = { frame = frame, parent = parent, levels = {} }
  rawset(frame, "GetCenter", function()
    local _, _, _, x, y = frame:GetPoint()
    return x, y
  end)
  case.region = factory.CreateFrame("Frame", nil, parent)
  rawset(case.region, "GetCenter", function()
    return 300, 700
  end)
  case.target = { region = case.region, relativePoint = "CENTER", x = 0, y = 0, scale = 2, level = 3000 }
  case.ride = IconRide.Create(frame, {
    theme = Theme,
    parent = parent,
    onLevel = function(level)
      case.levels[#case.levels + 1] = level
    end,
  })
  return case
end

local function tick(case, seconds)
  case.frame.scripts.OnUpdate(case.frame, seconds)
end

return function()
  -- test_ride_glides_then_pins_to_the_target
  do
    local case = build()
    case.ride.rideTo(case.target)
    assert(case.ride.isRiding(), "riding from the start")
    assert(case.frame:GetFrameLevel() == 3000, "above the window at once")
    assert(case.levels[1] == 3000, "the badge is told too")
    tick(case, SECONDS / 2)
    assert(case.frame.scripts.OnUpdate ~= nil, "still gliding")
    assert(case.frame:GetScale() > 1 and case.frame:GetScale() < 2, "growing, got " .. tostring(case.frame:GetScale()))
    tick(case, SECONDS)
    assert(case.frame.scripts.OnUpdate == nil, "the ticker stops")
    assert(case.frame:GetScale() == 2, "full portrait size")
    local _, relativeTo, relativePoint = case.frame:GetPoint()
    assert(relativeTo == case.region and relativePoint == "CENTER", "pinned, so it follows the window")
  end

  -- test_ride_home_restores_the_exact_anchor_scale_and_level
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    case.ride.rideHome()
    assert(not case.ride.isRiding(), "no longer riding")
    tick(case, SECONDS + 0.01)
    local point, relativeTo, relativePoint, x, y = case.frame:GetPoint()
    assert(point == "BOTTOMRIGHT" and relativeTo == case.parent and relativePoint == "BOTTOMRIGHT", "saved anchor back")
    assert(x == -20 and y == 40, "saved offsets back")
    assert(case.frame:GetScale() == 1, "normal size")
    assert(case.frame:GetFrameLevel() == 5, "normal level")
  end

  -- test_reopening_mid_glide_keeps_the_true_home
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    case.ride.rideHome()
    tick(case, SECONDS / 2)
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    case.ride.rideHome()
    tick(case, SECONDS + 0.01)
    local _, _, _, x, y = case.frame:GetPoint()
    assert(x == -20 and y == 40, "a half-way spot never becomes home")
  end

  -- test_adopt_makes_the_current_spot_home
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    rawset(case.frame, "GetCenter", function()
      return 150, 350
    end)
    rawset(case.frame, "GetEffectiveScale", function()
      return 2
    end)
    local state = case.ride.adoptHere()
    assert(state.anchorPoint == "CENTER" and state.relativePoint == "BOTTOMLEFT", "saved from the screen corner")
    assert(state.x == 300 and state.y == 700, "in normal-size units, got " .. tostring(state.x))
    rawset(case.frame, "GetEffectiveScale", function()
      return 1
    end)
    case.ride.rideHome()
    tick(case, SECONDS + 0.01)
    local point, _, _, x, y = case.frame:GetPoint()
    assert(point == "CENTER" and x == 300 and y == 700, "goes home to the new spot")
  end

  -- test_new_home_while_riding_is_where_the_button_returns
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    case.ride.setHome({ anchorPoint = "CENTER", relativePoint = "CENTER", x = 7, y = 8 })
    assert(case.frame:GetPoint() == "CENTER" and select(2, case.frame:GetPoint()) == case.region, "stays on the window for now")
    case.ride.rideHome()
    if case.frame.scripts.OnUpdate then
      tick(case, SECONDS + 0.01)
    end
    local point, relativeTo, relativePoint, x, y = case.frame:GetPoint()
    assert(point == "CENTER" and relativeTo == case.parent and relativePoint == "CENTER", "the reset spot")
    assert(x == 7 and y == 8, "the reset offsets")
  end

  -- test_target_losing_its_position_mid_glide_is_safe
  do
    local case = build()
    case.ride.rideTo(case.target)
    rawset(case.region, "GetCenter", function()
      return nil
    end)
    tick(case, SECONDS / 2)
    tick(case, SECONDS)
    assert(select(2, case.frame:GetPoint()) == case.region, "still arrives")
  end

  -- test_ride_home_when_not_riding_does_nothing
  do
    local case = build()
    case.ride.rideHome()
    assert(case.frame.scripts == nil or case.frame.scripts.OnUpdate == nil, "nothing to undo")
    assert(select(4, case.frame:GetPoint()) == -20, "anchor untouched")
  end

  -- test_second_ride_while_riding_retargets_without_a_new_home
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    case.target.scale = 3
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    assert(case.frame:GetScale() == 3, "new size")
    case.ride.rideHome()
    tick(case, SECONDS + 0.01)
    assert(select(4, case.frame:GetPoint()) == -20, "home unchanged")
  end
end
