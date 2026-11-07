local CompactDockFlowCase = require("tests.helpers.compact_dock_flow_case")

local build = CompactDockFlowCase.Build

return function()
  -- test_off_open_leaves_the_button_alone
  do
    local case = build()
    case.dockOn = false
    case.flow.open()
    assert(case.rides == 0 and case.flow.dockedIcon() == nil, "no ride, nothing docked")
    assert(case.rideHandlers ~= case.handlers, "a drag on the button still moves the button")
    assert(case.flow.isWindowPart(case.fab) == false, "the button is not part of the window")
    case.flow.syncIconSlot()
    assert(case.occupied == false, "the corner stays free for the title buttons")
  end

  -- test_off_window_still_grows_from_and_shrinks_into_the_button
  do
    local case = build()
    case.dockOn = false
    case.flow.open()
    assert(case.openedFrom == case.fab and case.played == case.openStep, "grows out of the floating button")
    case.frame.shown = false
    case.flow.close()
    assert(case.closedInto == case.fab and case.played == case.closeStep and case.homes == 0, "shrinks into it, no ride home")
  end

  -- test_off_does_not_place_the_window_on_the_button
  for _, dockOn in ipairs({ true, false }) do
    local case = build()
    case.dockOn, case.savedSpot = dockOn, false
    rawset(case.fab, "IsVisible", function()
      return true
    end)
    local before = { case.frame:GetPoint() }
    case.flow.open()
    local after = { case.frame:GetPoint() }
    if dockOn then
      assert(
        after[4] == 500 - 25 and after[5] == 600 + 25,
        "on: the corner spot lands on the button, got " .. tostring(after[4]) .. "," .. tostring(after[5])
      )
    else
      for i = 1, 5 do
        assert(after[i] == before[i], "off: the window opens at its own spot (anchor part " .. i .. ")")
      end
    end
  end

  -- test_on_to_off_while_open_sends_the_button_home_and_restores_the_layout
  do
    local case = build()
    case.flow.open()
    case.flow.syncIconSlot()
    case.dockOn = false
    case.flow.dock()
    assert(case.finished == 1, "the open animation is finished first")
    assert(case.homes == 1 and case.homeInstant ~= true and case.step == nil, "home by gliding, no closing step")
    assert(case.rideHandlers == nil and case.flow.dockedIcon() == nil, "drag handlers off, nothing docked")
    assert(case.occupied == false and case.flow.isWindowPart(case.fab) == false, "corner free, button not part of the window")
    case.frame.shown = false
    case.flow.close()
    assert(case.homes == 1 and case.closedInto == case.fab, "closing later does not ride again, still shrinks into the button")
  end

  -- test_on_to_off_jumps_when_window_animation_is_off
  do
    local case = build()
    case.flow.open()
    case.animation, case.dockOn = false, false
    case.flow.dock()
    assert(case.homes == 1 and case.homeInstant == true, "jumps home")
  end

  -- test_off_to_on_while_open_docks_the_button_without_replaying_the_opening
  do
    local case = build()
    case.dockOn = false
    case.flow.open()
    case.frame:Show()
    case.dockOn = true
    case.flow.dock()
    assert(case.rides == 1 and case.step == nil and case.rideInstant ~= true, "glides onto the spot, no opening to replay")
    assert(case.rideHandlers == case.handlers and case.flow.dockedIcon() == case.icon, "drag moves the window again")
    assert(case.rideStrata == case.frame:GetFrameStrata(), "with the window's strata")
    case.flow.syncIconSlot()
    assert(case.occupied == true, "the corner is taken")
  end

  -- test_off_re_dock_with_nothing_docked_stays_undocked
  do
    local case = build()
    case.dockOn = false
    case.flow.open()
    case.frame:Show()
    case.flow.dock()
    assert(case.rides == 0 and case.flow.dockedIcon() == nil, "a size or mode change does not dock it while the option is off")
  end

  -- test_close_during_the_ride_then_off_then_open_leaves_the_button_home
  do
    local case = build()
    case.flow.open()
    case.frame.shown = false
    case.flow.close()
    case.dockOn = false
    case.frame.shown = true
    case.flow.open()
    assert(case.rides == 1 and case.homes == 1, "no second ride: it stays on its way home")
    assert(case.icon.isRiding() == false and case.flow.dockedIcon() == nil and case.rideHandlers == nil, "not riding, not docked")
  end

  -- test_a_missing_option_counts_as_on
  do
    local case = build({ omitDockOption = true })
    case.flow.open()
    assert(case.rides == 1 and case.flow.dockedIcon() == case.icon, "docks like on")
  end
end
