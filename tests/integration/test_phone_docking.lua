local PhoneWindow = require("tests.helpers.phone_window")

-- What the window owes the button docked on it: its place in the draw order,
-- and room on screen for the spot that sticks out past its corner.

local build = PhoneWindow.Build

local function at(region, left, top)
  rawset(region, "GetLeft", function()
    return left
  end)
  rawset(region, "GetTop", function()
    return top
  end)
end

-- A spot sticking out 7 left of the window and 17 above it.
local function layOut(case)
  at(case.window.frame, 100, 900)
  at(case.rodeTo.region, 93, 917)
end

return function()
  -- test_the_docked_button_follows_the_window_back_and_forward
  do
    local case = build()
    local frame = case.window.frame
    frame:Show()
    frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN")
    assert(frame:GetFrameStrata() == "MEDIUM", "a click elsewhere sends the window back")
    assert(case.rideStrata == "MEDIUM", "and the button with it")
    frame.scripts.OnMouseDown(frame)
    assert(case.rideStrata == "HIGH", "a click on the window brings both forward")
  end

  -- test_pressing_the_docked_button_keeps_the_window_forward
  do
    local case = build()
    local frame = case.window.frame
    frame:Show()
    local saved = rawget(_G, "GetMouseFocus")
    rawset(_G, "GetMouseFocus", function()
      return case.fab
    end)
    frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN")
    rawset(_G, "GetMouseFocus", saved)
    assert(frame:GetFrameStrata() == "HIGH", "a press to close or drag is on the window, not elsewhere")
    assert(case.rideStrata == "HIGH", "so the button stays with it")
  end

  -- test_the_button_takes_the_windows_strata_on_docking
  do
    local case = build()
    case.window.frame:Show()
    assert(case.rideStrata == "HIGH", "a reopen mid-glide may find it still down with the old window")
  end

  -- test_a_button_not_on_the_window_keeps_its_strata
  do
    local case = build({
      getDockIcon = function()
        return nil
      end,
    })
    local frame = case.window.frame
    frame:Show()
    frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN")
    assert(case.rideStrata == nil, "nothing docked")
  end

  -- test_opening_clamps_the_window_over_its_spot
  do
    local case = build()
    local frame = case.window.frame
    frame:Show()
    layOut(case)
    frame:Hide()
    frame:Show()
    local left, _, top = frame:GetClampRectInsets()
    assert(left == -7 and top == 17, "got " .. tostring(left) .. "," .. tostring(top))
  end

  -- test_a_spot_laid_out_a_frame_late_still_clamps
  do
    local case = build()
    local saved = rawget(_G, "C_Timer")
    local later = {}
    rawset(_G, "C_Timer", {
      After = function(_seconds, fn)
        later[#later + 1] = fn
      end,
    })
    case.window.frame:Show()
    rawset(_G, "C_Timer", saved)
    assert(#later == 1, "asks again next frame")
    layOut(case)
    later[1]()
    assert(select(3, case.window.frame:GetClampRectInsets()) == 17, "measured once it exists")
  end
end
