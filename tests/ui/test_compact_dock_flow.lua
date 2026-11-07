local CompactDockFlowCase = require("tests.helpers.compact_dock_flow_case")

local build = CompactDockFlowCase.Build

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
    assert(case.finished == 1 and case.rides == 2 and case.step == nil and case.rideInstant ~= true, "re-docks with no opening to replay, gliding")
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

  -- test_window_animation_off_opens_and_closes_with_a_jump
  do
    local case = build()
    case.animation = false
    case.flow.open()
    assert(case.rideInstant == true and case.step == nil, "the button jumps onto the spot")
    case.frame.shown = false
    case.flow.close()
    assert(case.homeInstant == true and case.step == nil and case.closedInto == nil, "home at once, no shrink")
  end

  -- test_window_animation_off_makes_a_re_dock_jump
  do
    local case = build()
    case.flow.open()
    case.animation = false
    case.flow.dock()
    assert(case.rides == 2 and case.rideInstant == true, "a re-dock jumps when Window animation is off")
  end

  -- test_window_animation_on_keeps_the_gliding_ride
  do
    local case = build()
    case.flow.open()
    assert(not case.rideInstant and case.step == case.openStep, "unchanged when on")
  end

  -- test_the_button_rides_the_corner_spot_and_takes_it
  do
    local case = build()
    case.flow.open()
    case.flow.syncIconSlot()
    assert(case.rodeTo.region == case.slot and case.flow.spot() == case.slot, "the corner spot")
    assert(case.occupied == true, "and the title buttons clear it")
  end

  -- test_opening_places_the_window_with_the_corner_spot_on_the_button
  do
    local case = build()
    case.savedSpot = false
    rawset(case.fab, "IsVisible", function()
      return true
    end)
    case.flow.open()
    local _, _, _, x, y = case.frame:GetPoint()
    -- the spot centre is (25, -25) from the window corner; the button sits at (500, 600)
    assert(x == 500 - 25 and y == 600 + 25, "the corner spot lands on the button, got " .. tostring(x) .. "," .. tostring(y))
  end

  -- test_the_window_grows_from_and_shrinks_into_the_button
  do
    local case = build()
    case.flow.open()
    assert(case.openedFrom == case.fab and case.step == case.openStep, "grows out of the button")
    case.frame.shown = false
    case.flow.close()
    assert(case.closedInto == case.fab and case.homes == 1, "and shrinks back into it")
  end

  -- test_a_button_appearing_on_an_open_window_follows_window_animation
  for _, animation in ipairs({ false, true }) do
    local case = build()
    case.animation, case.noIcon = animation, true
    case.flow.open()
    case.frame:Show()
    case.noIcon = false
    case.flow.dock()
    assert(case.rides == 1 and case.step == nil, "docks where it stands with no opening to replay")
    assert((case.rideInstant == true) == not animation, "animation " .. tostring(animation) .. ": instant is " .. tostring(case.rideInstant))
  end
end
