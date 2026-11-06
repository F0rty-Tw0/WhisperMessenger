local PhoneWindow = require("tests.helpers.phone_window")
local Theme = require("WhisperMessenger.UI.Theme")

-- What the window owes the button docked on it: its place in the draw order,
-- room on screen for the spot that sticks out past its corner, and saving
-- where it goes.

local L = Theme.LAYOUT

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

local function titleOffset(case)
  return select(4, case.window.newConversationButton:GetPoint())
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

  -- test_dragging_by_the_button_saves_the_window
  do
    local case = build()
    case.window.frame:Show()
    case.rideHandlers.beginDrag()
    case.rideHandlers.endDrag()
    assert(case.saved.state ~= nil, "players who later lose the button reopen it there")
    assert(case.saved.state.width == L.PHONE_WINDOW_WIDTH, "got " .. tostring(case.saved.state.width))
    assert(case.adopted == 1, "the button's home moves once")
  end

  -- test_reset_brings_the_window_to_the_screen_centre
  do
    local case = build()
    local frame = case.window.frame
    frame:Show()
    frame:SetSize(500, 700)
    local reset = case.window.resetWindowButton
    reset.scripts.OnClick(reset)
    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    assert(point == "TOPLEFT" and relativePoint == "CENTER", "got " .. tostring(point) .. "," .. tostring(relativePoint))
    assert(relativeTo == frame:GetParent(), "on the screen")
    assert(x == -L.PHONE_WINDOW_WIDTH / 2 and y == L.PHONE_WINDOW_HEIGHT / 2, "got " .. tostring(x) .. "," .. tostring(y))
    assert(frame.width == L.PHONE_WINDOW_WIDTH, "phone size, got " .. tostring(frame.width))
    assert(case.adopted == 0, "the button's own home stays: it has its own reset")
  end

  -- test_reset_under_settings_centres_the_phone_sized_window
  do
    local case = build()
    local frame = case.window.frame
    frame:Show()
    case.window.setOptionsVisible(true)
    local reset = case.window.resetWindowButton
    reset.scripts.OnClick(reset)
    local _, _, _, x = frame:GetPoint()
    assert(x == -L.PHONE_WINDOW_WIDTH / 2, "settings close to a centred phone window, got " .. tostring(x))
    assert(frame.width > L.PHONE_WINDOW_WIDTH, "still wide for settings")
  end

  -- test_the_rail_saves_through_the_phone_window
  do
    local case = build({ state = { contactsCollapsed = true } })
    case.window.frame:Show()
    case.window.setOptionsVisible(true)
    local search = case.window.contactsRailSearchButton
    search.scripts.OnClick(search)
    assert(case.saved.state == nil, "a wide window is never the saved size")
  end

  -- test_with_no_button_the_title_buttons_use_the_corner
  do
    local case = build({
      getDockIcon = function()
        return nil
      end,
    })
    case.window.frame:Show()
    assert(titleOffset(case) == L.TITLE_BAR_INSET_X, "got " .. tostring(titleOffset(case)))
  end

  -- test_a_docked_button_keeps_the_corner_clear
  do
    local case = build()
    case.window.frame:Show()
    assert(titleOffset(case) == L.TITLE_BAR_INSET_X + L.PHONE_ICON_SLOT_CLEARANCE, "got " .. tostring(titleOffset(case)))
  end

  -- test_the_corner_follows_the_icon_mode_with_the_window_open
  do
    local dockable = true
    local case
    case = build({
      getDockIcon = function()
        return dockable and case.icon or nil
      end,
    })
    case.window.frame:Show()
    dockable = false
    case.window.dockPhoneIcon()
    assert(titleOffset(case) == L.TITLE_BAR_INSET_X, "the button left, so the room comes back")
    dockable = true
    case.window.dockPhoneIcon()
    assert(titleOffset(case) == L.TITLE_BAR_INSET_X + L.PHONE_ICON_SLOT_CLEARANCE, "and it is back on the spot")
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
