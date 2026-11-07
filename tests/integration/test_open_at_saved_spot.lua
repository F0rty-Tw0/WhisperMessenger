local PhoneWindow = require("tests.helpers.phone_window")
local PhoneRuntime = require("tests.helpers.phone_runtime")
local Rig = require("tests.helpers.grow_rig")

-- Open at saved spot, in both layouts: off, the window opens with its icon
-- spot on the floating button and the button's home follows the window; on,
-- the window opens where it was last moved and the button stays home.

local LAYOUTS = {
  { name = "compact", phone = true },
  { name = "regular", phone = false },
}

-- Window rect 100..460 x 100..740 (left 100, top 740), button centre (800, 500),
-- the icon slot centre 25 right of and 25 below the window's top-left corner.
local function laidOut(phone, savedSpot, extra)
  local state = { savedSpot = savedSpot }
  local options = {
    phoneLayout = phone,
    isOpenAtSavedSpot = function()
      return state.savedSpot
    end,
  }
  for key, value in pairs(extra or {}) do
    options[key] = value
  end
  local case = PhoneWindow.Build(options)
  case.window.frame:Show()
  local slot = case.rodeTo and case.rodeTo.region
  case.window.frame:Hide()
  PhoneWindow.Lay(case)
  if slot then
    rawset(slot, "GetCenter", function()
      return 125, 715
    end)
  end
  case.state = state
  return case
end

local function sameAnchor(before, after, name, what)
  for i = 1, 5 do
    assert(after[i] == before[i], name .. ": " .. what .. " (anchor part " .. i .. ")")
  end
end

return function()
  for _, layout in ipairs(LAYOUTS) do
    local name, phone = layout.name, layout.phone

    -- test_off_opens_with_the_spot_on_the_button
    do
      local case = laidOut(phone, false)
      case.window.frame:Show()
      local point, relativeTo, relativePoint, x, y = case.window.frame:GetPoint()
      assert(point == "TOPLEFT" and relativeTo == case.uiParent and relativePoint == "BOTTOMLEFT", name .. ": screen-anchored")
      assert(x == 775 and y == 525, name .. ": button 800,500 minus the spot's 25,-25 offset, got " .. tostring(x) .. "," .. tostring(y))
    end

    -- test_on_opens_at_the_saved_spot_and_leaves_the_button_home
    do
      local case = laidOut(phone, true)
      local before = { case.window.frame:GetPoint() }
      case.window.frame:Show()
      sameAnchor(before, { case.window.frame:GetPoint() }, name, "the saved spot moved on open")
      case.window.frame.scripts.OnDragStop(case.window.frame)
      assert(case.adopted == 0, name .. ": the button's home stays put")
    end

    -- test_off_with_a_hidden_widget_opens_at_the_saved_spot_and_never_places
    do
      local case = laidOut(phone, false)
      case.fab:Hide()
      local before = { case.window.frame:GetPoint() }
      case.window.frame:Show()
      sameAnchor(before, { case.window.frame:GetPoint() }, name, "placed although the widget is hidden")
    end

    -- test_off_in_minimap_mode_grows_from_the_minimap_icon_at_the_saved_spot
    do
      local minimap = Rig.icon(1500, 100, 1532, 132)
      local case = laidOut(phone, false, {
        getDockIcon = function()
          return nil
        end,
        getGrowSource = function()
          return minimap
        end,
      })
      local before = { case.window.frame:GetPoint() }
      case.window.frame:Show()
      sameAnchor(before, { case.window.frame:GetPoint() }, name, "placed in minimap mode")
      assert(Rig.running(Rig.ghostOf(case.window.frame)), name .. ": still grows from the minimap icon")
    end

    -- test_off_moving_the_window_moves_the_button_home
    do
      local case = laidOut(phone, false)
      case.window.frame:Show()
      case.window.frame.scripts.OnDragStop(case.window.frame)
      assert(case.adopted == 1, name .. ": adopted once on a window drag, got " .. case.adopted)
      case.rideHandlers.endDrag()
      assert(case.adopted == 2, name .. ": and on a docked-button drag, got " .. case.adopted)
    end

    -- test_off_alt_z_never_adopts_places_or_sends_the_button_home
    do
      local case = laidOut(phone, false)
      local frame = case.window.frame
      local homes = case.homes
      frame:Show()
      local placed = { frame:GetPoint() }
      frame.shown = true
      PhoneWindow.Fire(frame, "OnHide")
      PhoneWindow.Fire(frame, "OnShow")
      sameAnchor(placed, { frame:GetPoint() }, name, "Alt+Z moved the window")
      assert(case.adopted == 0 and case.homes == homes, name .. ": Alt+Z adopts nothing and sends nothing home")
    end

    -- test_changing_the_switch_applies_at_the_next_open
    do
      local case = laidOut(phone, true)
      case.state.savedSpot = false
      case.window.frame:Show()
      assert(select(4, case.window.frame:GetPoint()) == 775, name .. ": read live, no reload")
    end
  end

  -- test_real_runtime_off_adopts_the_window_move_unless_the_icon_is_locked
  for _, layout in ipairs(LAYOUTS) do
    for _, locked in ipairs({ false, true }) do
      PhoneRuntime.Run({ phoneLayout = layout.phone, lockToggleIcon = locked }, function(runtime)
        runtime.toggle()
        local icon, frame = runtime.icon, runtime.window.frame
        rawset(icon.frame, "GetCenter", function()
          return 800, 500
        end)
        local homeBefore = runtime.characterState.icon
        frame.scripts.OnDragStop(frame)
        if locked then
          assert(runtime.characterState.icon == homeBefore, layout.name .. ": locked, the icon position is never written")
        else
          assert(runtime.characterState.icon ~= homeBefore, layout.name .. ": unlocked, the window move saves the button home")
        end
      end)
    end
  end
end
