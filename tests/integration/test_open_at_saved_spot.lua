local CompactWindow = require("tests.helpers.compact_window")
local CompactRuntime = require("tests.helpers.compact_runtime")
local Rig = require("tests.helpers.grow_rig")
local Theme = require("WhisperMessenger.UI.Theme")

-- Open at saved spot, in both layouts: off, the window opens with its icon
-- spot on the floating button and the button's home follows the window; on,
-- the window opens where it was last moved and the button stays home.

local L = Theme.LAYOUT

local LAYOUTS = {
  { name = "compact", compactMode = true },
  { name = "regular", compactMode = false },
}

-- Window rect 100..460 x 100..740 (left 100, top 740), button centre (800, 500),
-- the icon slot centre 25 right of and 25 below the window's top-left corner.
local function laidOut(compactMode, savedSpot, extra)
  local state = { savedSpot = savedSpot }
  local options = {
    compactLayout = compactMode,
    isOpenAtSavedSpot = function()
      return state.savedSpot
    end,
  }
  for key, value in pairs(extra or {}) do
    options[key] = value
  end
  local case = CompactWindow.Build(options)
  case.window.frame:Show()
  local slot = case.rodeTo and case.rodeTo.region
  case.window.frame:Hide()
  CompactWindow.Lay(case)
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
    local name, compactMode = layout.name, layout.compactMode

    -- test_off_opens_with_the_spot_on_the_button
    do
      local case = laidOut(compactMode, false)
      case.window.frame:Show()
      local point, relativeTo, relativePoint, x, y = case.window.frame:GetPoint()
      assert(point == "TOPLEFT" and relativeTo == case.uiParent and relativePoint == "BOTTOMLEFT", name .. ": screen-anchored")
      assert(x == 775 and y == 525, name .. ": button 800,500 minus the spot's 25,-25 offset, got " .. tostring(x) .. "," .. tostring(y))
    end

    -- test_on_opens_at_the_saved_spot_and_leaves_the_button_home
    do
      local case = laidOut(compactMode, true)
      local before = { case.window.frame:GetPoint() }
      case.window.frame:Show()
      sameAnchor(before, { case.window.frame:GetPoint() }, name, "the saved spot moved on open")
      case.window.frame.scripts.OnDragStop(case.window.frame)
      assert(case.adopted == 0, name .. ": the button's home stays put")
    end

    -- test_off_with_a_hidden_widget_opens_at_the_saved_spot_and_never_places
    do
      local case = laidOut(compactMode, false)
      case.fab:Hide()
      local before = { case.window.frame:GetPoint() }
      case.window.frame:Show()
      sameAnchor(before, { case.window.frame:GetPoint() }, name, "placed although the widget is hidden")
    end

    -- test_off_in_minimap_mode_grows_from_the_minimap_icon_at_the_saved_spot
    do
      local minimap = Rig.icon(1500, 100, 1532, 132)
      local case = laidOut(compactMode, false, {
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
      local case = laidOut(compactMode, false)
      case.window.frame:Show()
      case.window.frame.scripts.OnDragStop(case.window.frame)
      assert(case.adopted == 1, name .. ": adopted once on a window drag, got " .. case.adopted)
      case.rideHandlers.endDrag()
      assert(case.adopted == 2, name .. ": and on a docked-button drag, got " .. case.adopted)
    end

    -- test_off_alt_z_never_adopts_places_or_sends_the_button_home
    do
      local case = laidOut(compactMode, false)
      local frame = case.window.frame
      local homes = case.homes
      frame:Show()
      local placed = { frame:GetPoint() }
      frame.shown = true
      CompactWindow.Fire(frame, "OnHide")
      CompactWindow.Fire(frame, "OnShow")
      sameAnchor(placed, { frame:GetPoint() }, name, "Alt+Z moved the window")
      assert(case.adopted == 0 and case.homes == homes, name .. ": Alt+Z adopts nothing and sends nothing home")
    end

    -- test_off_reset_window_position_moves_the_button_home_with_the_window
    do
      local case = laidOut(compactMode, false, {
        onResetWindowPosition = function()
          return not compactMode and { anchorPoint = "CENTER", relativePoint = "CENTER", x = 0, y = 0 } or nil
        end,
      })
      local frame = case.window.frame
      frame:Show()
      local atAdopt
      local adopt = case.icon.adoptRidePosition
      case.icon.adoptRidePosition = function()
        atAdopt = { frame:GetPoint() }
        adopt()
      end
      local reset = case.window.resetWindowButton
      reset.scripts.OnClick(reset)
      assert(case.adopted == 1, name .. ": the reset moved the window, so the button's home follows, got " .. case.adopted)
      assert(
        atAdopt[4] == (compactMode and -L.COMPACT_WINDOW_WIDTH / 2 or 0),
        name .. ": adopted after the window moved, got " .. tostring(atAdopt[4])
      )
    end

    -- test_on_reset_window_position_leaves_the_button_home
    do
      local case = laidOut(compactMode, true)
      case.window.frame:Show()
      local reset = case.window.resetWindowButton
      reset.scripts.OnClick(reset)
      assert(case.adopted == 0, name .. ": the button's home stays put, got " .. case.adopted)
    end

    -- test_changing_the_switch_applies_at_the_next_open
    do
      local case = laidOut(compactMode, true)
      case.state.savedSpot = false
      case.window.frame:Show()
      assert(select(4, case.window.frame:GetPoint()) == 775, name .. ": read live, no reload")
    end
  end

  -- test_real_runtime_off_adopts_the_window_move_unless_the_icon_is_locked
  for _, layout in ipairs(LAYOUTS) do
    for _, locked in ipairs({ false, true }) do
      CompactRuntime.Run({ compactLayout = layout.compactMode, lockToggleIcon = locked, openAtSavedSpot = false }, function(runtime)
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
