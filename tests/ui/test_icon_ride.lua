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
  parent:Show()
  frame:Show()
  local case = { frame = frame, parent = parent, levels = {}, ridingChanges = {} }
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
    onRidingChanged = function(riding)
      case.ridingChanges[#case.ridingChanges + 1] = tostring(riding)
    end,
  })
  return case
end

local FRAME = 1 / 60

-- Runs the glide frame by frame, as the client does.
local function tick(case, seconds)
  local remaining = seconds
  while remaining > 0 and case.frame.scripts.OnUpdate do
    case.frame.scripts.OnUpdate(case.frame, math.min(FRAME, remaining))
    remaining = remaining - FRAME
  end
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

  -- test_riding_is_reported_on_leaving_and_on_landing_home
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    case.ride.rideHome()
    assert(table.concat(case.ridingChanges, ",") == "true", "still away while gliding home")
    tick(case, SECONDS + 0.01)
    assert(table.concat(case.ridingChanges, ",") == "true,false", "home once landed: " .. table.concat(case.ridingChanges, ","))
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

  -- test_a_hidden_button_goes_home_at_once
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    case.frame:Hide()
    local finished = 0
    case.ride.rideHome(function(t)
      finished = t == 1 and finished + 1 or finished
    end)
    assert(case.frame.scripts.OnUpdate == nil, "a hidden frame never ticks, so nothing waits on it")
    assert(select(4, case.frame:GetPoint()) == -20, "already home")
    assert(case.frame:GetScale() == 1, "normal size")
    assert(finished == 1, "the shared clock still ends")
  end

  -- test_riding_follows_the_windows_strata_at_the_same_level
  do
    local case = build()
    case.frame:SetFrameStrata("HIGH")
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    case.levels = {}
    case.ride.setStrata("MEDIUM")
    assert(case.frame:GetFrameStrata() == "MEDIUM", "goes back with the window")
    assert(case.frame:GetFrameLevel() == 3000, "still above the window")
    assert(case.levels[1] == 3000, "the badge's level is set again")
  end

  -- test_going_home_returns_to_the_buttons_own_strata
  do
    local case = build()
    case.frame:SetFrameStrata("HIGH")
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    case.ride.setStrata("MEDIUM")
    case.ride.rideHome()
    assert(case.frame:GetFrameStrata() == "MEDIUM", "the glide stays where the window was: no pop over what covers it")
    tick(case, SECONDS + 0.01)
    assert(case.frame:GetFrameStrata() == "HIGH", "home again")
    assert(case.frame:GetFrameLevel() == 5, "and its own level")
  end

  -- test_a_button_at_home_ignores_the_windows_strata
  do
    local case = build()
    case.frame:SetFrameStrata("HIGH")
    case.ride.setStrata("MEDIUM")
    assert(case.frame:GetFrameStrata() == "HIGH", "not on the window")
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

  -- test_every_frame_reports_the_shared_clock_ending_on_one
  do
    local case = build()
    local steps = {}
    case.ride.rideTo(case.target, function(t, p)
      steps[#steps + 1] = { t, p }
    end)
    tick(case, SECONDS + 0.05)
    assert(#steps > 3, "a step per frame, got " .. #steps)
    assert(steps[1][2] > steps[1][1], "eased ahead of linear time")
    local last = steps[#steps]
    assert(last[1] == 1 and last[2] == 1, "ends exactly on one")
  end

  -- test_a_hitch_pauses_the_glide_instead_of_skipping_it
  do
    local case = build()
    local steps = 0
    case.ride.rideTo(case.target, function()
      steps = steps + 1
    end)
    case.frame.scripts.OnUpdate(case.frame, 2)
    assert(case.frame.scripts.OnUpdate ~= nil, "a slow frame must not eat the animation")
    assert(steps == 1, "it moves on by one frame's worth")
  end

  -- test_ride_home_reports_steps_too
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.05)
    local last
    case.ride.rideHome(function(t)
      last = t
    end)
    tick(case, SECONDS + 0.05)
    assert(last == 1, "the closing panel shares the clock")
  end

  -- test_no_position_still_finishes_the_step
  do
    local case = build()
    rawset(case.frame, "GetCenter", function()
      return nil
    end)
    local last
    case.ride.rideTo(case.target, function(t)
      last = t
    end)
    assert(last == 1, "an unplaced icon cannot leave the window held")
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

  -- test_instant_ride_arrives_at_once_and_reports_one
  do
    local case = build()
    local steps = {}
    case.ride.rideTo(case.target, function(t, p)
      steps[#steps + 1] = { t, p }
    end, true)
    assert(case.frame.scripts.OnUpdate == nil, "no glide: nothing ticks")
    assert(case.ride.isRiding(), "riding from the start")
    assert(case.frame:GetScale() == 2 and case.frame:GetFrameLevel() == 3000, "landed: size and level")
    local _, relativeTo, relativePoint = case.frame:GetPoint()
    assert(relativeTo == case.region and relativePoint == "CENTER", "pinned to the target")
    assert(#steps == 1 and steps[1][1] == 1 and steps[1][2] == 1, "one step, ending on one")
  end

  -- test_instant_ride_home_restores_at_once_and_reports_one
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS + 0.01)
    local steps = {}
    case.ride.rideHome(function(t, p)
      steps[#steps + 1] = { t, p }
    end, true)
    assert(case.frame.scripts.OnUpdate == nil, "no glide home")
    local point, relativeTo, relativePoint, x, y = case.frame:GetPoint()
    assert(point == "BOTTOMRIGHT" and relativeTo == case.parent and relativePoint == "BOTTOMRIGHT", "saved anchor back")
    assert(x == -20 and y == 40 and case.frame:GetScale() == 1 and case.frame:GetFrameLevel() == 5, "saved offsets, size, level back")
    assert(not case.ride.isRiding(), "no longer riding")
    assert(table.concat(case.ridingChanges, ",") == "true,false", "landing home reported")
    assert(#steps == 1 and steps[1][1] == 1 and steps[1][2] == 1, "one step, ending on one")
  end

  -- test_instant_ride_home_cancels_a_glide_in_progress
  do
    local case = build()
    case.ride.rideTo(case.target)
    tick(case, SECONDS / 2)
    assert(case.frame.scripts.OnUpdate ~= nil, "gliding out")
    case.ride.rideHome(nil, true)
    assert(case.frame.scripts.OnUpdate == nil, "the old glide is gone")
    assert(select(4, case.frame:GetPoint()) == -20 and case.frame:GetScale() == 1, "home at once")
  end
end
