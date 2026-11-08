local CompactWindow = require("tests.helpers.compact_window")
local CompactRuntime = require("tests.helpers.compact_runtime")
local RetailHud = require("tests.helpers.retail_hud")
local Theme = require("WhisperMessenger.UI.Theme")
local DockWiring = require("WhisperMessenger.UI.MessengerWindow.MessengerWindow.DockWiring")
local SettingsHandler = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.SettingsHandler")
local withPopups = require("tests.helpers.reload_popups").With

local L = Theme.LAYOUT
local LAYOUTS = { { name = "compact", compactMode = true }, { name = "regular", compactMode = false } }

local function eachLayout(run)
  for _, layout in ipairs(LAYOUTS) do
    run(layout.name, layout.compactMode)
  end
end

local function titleOffset(case)
  return select(4, case.window.newConversationButton:GetPoint())
end

local function at(region, left, top)
  rawset(region, "GetLeft", function()
    return left
  end)
  rawset(region, "GetTop", function()
    return top
  end)
end

return function()
  -- test_opening_docks_the_button_on_the_spot_and_clears_the_title_buttons
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({ compactLayout = compactMode })
    case.window.frame:Show()
    assert(case.rides == 1 and case.rodeTo.region ~= nil, name .. ": the button rides the spot, got " .. case.rides)
    assert(case.rideHandlers ~= nil and case.rideStrata == "HIGH", name .. ": drag handlers and the window's strata")
    assert(
      titleOffset(case) == L.TITLE_BAR_INSET_X + L.COMPACT_ICON_SLOT_CLEARANCE,
      name .. ": title buttons shifted, got " .. tostring(titleOffset(case))
    )
  end)

  -- test_closing_sends_the_button_home
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({ compactLayout = compactMode })
    case.window.frame:Show()
    case.window.closeButton.scripts.OnClick(case.window.closeButton)
    assert(case.homes == 1, name .. ": home on close, got " .. case.homes)
  end)

  -- test_dragging_by_the_button_moves_and_saves_the_window
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({ compactLayout = compactMode })
    local frame, moved = case.window.frame, 0
    rawset(frame, "StartMoving", function()
      moved = moved + 1
    end)
    frame:Show()
    case.rideHandlers.beginDrag()
    case.rideHandlers.endDrag()
    assert(moved == 1, name .. ": the window moves")
    assert(case.saved.state ~= nil and case.saved.state.width == frame:GetWidth(), name .. ": the window is saved at its width")
  end)

  -- test_dragging_by_the_button_starts_the_move_from_the_cursor
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({ compactLayout = compactMode })
    local frame, fromCursor = case.window.frame, nil
    rawset(frame, "StartMoving", function(_self, alwaysStartFromMouse)
      fromCursor = alwaysStartFromMouse
    end)
    frame:Show()
    case.rideHandlers.beginDrag()
    assert(fromCursor == true, name .. ": the window never got the press, so the move starts from the cursor, got " .. tostring(fromCursor))
  end)

  -- test_strata_follows_the_window
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({ compactLayout = compactMode })
    local frame = case.window.frame
    frame:Show()
    frame.scripts.OnEvent(frame, "GLOBAL_MOUSE_DOWN")
    assert(case.rideStrata == "MEDIUM", name .. ": a click elsewhere sends the button back with the window")
    frame.scripts.OnMouseDown(frame)
    assert(case.rideStrata == "HIGH", name .. ": a click on the window brings both forward")
  end)

  -- test_dock_compact_icon_re_docks_in_both_layouts  (scale, icon mode, icon size route here)
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({ compactLayout = compactMode })
    assert(type(case.window.dockCompactIcon) == "function", name .. ": exposed")
    case.window.frame:Show()
    case.window.dockCompactIcon()
    assert(case.rides == 2, name .. ": takes its spot again, got " .. case.rides)
  end)

  -- test_the_corner_follows_the_icon_mode_with_the_window_open
  eachLayout(function(name, compactMode)
    local dockable, case = true, nil
    case = CompactWindow.Build({
      compactLayout = compactMode,
      getDockIcon = function()
        return dockable and case.icon or nil
      end,
    })
    case.window.frame:Show()
    dockable = false
    case.window.dockCompactIcon()
    assert(titleOffset(case) == L.TITLE_BAR_INSET_X, name .. ": room comes back when the button leaves")
    dockable = true
    case.window.dockCompactIcon()
    assert(titleOffset(case) == L.TITLE_BAR_INSET_X + L.COMPACT_ICON_SLOT_CLEARANCE, name .. ": and goes again")
  end)

  -- test_opening_clamps_the_window_over_its_spot
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({ compactLayout = compactMode })
    local frame = case.window.frame
    frame:Show()
    at(frame, 100, 900)
    at(case.rodeTo.region, 93, 917)
    frame:Hide()
    frame:Show()
    local left, _, top = frame:GetClampRectInsets()
    assert(left == -7 and top == 17, name .. ": got " .. tostring(left) .. "," .. tostring(top))
  end)

  -- test_alt_z_hide_and_show_neither_closes_nor_replays  (Review Focus 3: grow and dock part)
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({ compactLayout = compactMode })
    local frame = case.window.frame
    frame:Show()
    case.step(1, 1)
    frame.shown = true
    CompactWindow.Fire(frame, "OnHide")
    assert(case.homes == 0, name .. ": Alt+Z hid the parent, not the window")
    CompactWindow.Fire(frame, "OnShow")
    assert(frame:GetAlpha() == 1 and case.homes == 0, name .. ": coming back replays nothing")
  end)

  -- test_a_runtime_style_switch_attaches_nothing_twice  (Review Focus 4)
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({ compactLayout = compactMode })
    local frame = case.window.frame
    local shows, hides = #frame._hookScripts.OnShow, #frame._hookScripts.OnHide
    withPopups(function(popups)
      local onChange = SettingsHandler.Create({
        runtime = { store = { config = {} }, compactLayoutActive = compactMode, window = case.window },
        accountSettings = {},
      })
      onChange("compactLayout", not compactMode)
      _G.StaticPopupDialogs[popups.shown[1]].OnCancel()
    end)
    assert(#frame._hookScripts.OnShow == shows and #frame._hookScripts.OnHide == hides, name .. ": hook counts unchanged")
    frame:Show()
    assert(case.rides == 1, name .. ": one dock, not two, got " .. case.rides)
  end)

  -- test_the_regular_window_docks_the_real_button_and_it_stays_clickable  (acceptance: Classic and Retail chrome)
  local function clickable(label, settings)
    CompactRuntime.Run(settings, function(runtime)
      runtime.toggle()
      local icon = runtime.icon
      assert(icon.isRiding(), label .. ": rides the regular window")
      icon.frame.scripts.OnClick(icon.frame, "LeftButton")
      assert(not runtime.window.frame:IsShown(), label .. ": a click on the docked button closes the window")
      assert(not icon.isRiding(), label .. ": and it heads home")
    end)
  end
  clickable("regular custom", { compactLayout = false, hudStyle = "off" })
  clickable("regular classic", { compactLayout = false, hudStyle = "classic" })
  RetailHud.With(function()
    clickable("regular retail", { compactLayout = false, hudStyle = "retail" })
  end)

  -- test_classic_grow_is_gone
  assert(not pcall(require, "WhisperMessenger.UI.MessengerWindow.MessengerWindow.ClassicGrow"), "module removed")
  for line in io.lines("WhisperMessenger.toc") do
    assert(not string.find(line, "ClassicGrow", 1, true), "TOC still lists " .. line)
  end

  -- test_window_animation_off_makes_the_button_jump_and_a_re_dock_jump
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({
      compactLayout = compactMode,
      isGrowAnimationOn = function()
        return false
      end,
    })
    local frame = case.window.frame
    frame:Show()
    assert(case.instant == true and case.step == nil, name .. ": the button jumps onto the spot")
    case.window.dockCompactIcon()
    assert(case.rides == 2 and case.instant == true, name .. ": a re-dock jumps too")
    frame:Hide()
    assert(case.homeInstant == true, name .. ": and jumps home")
  end)

  -- test_a_re_dock_keeps_the_screen_clamp_reaching_over_the_corner
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({ compactLayout = compactMode })
    local frame = case.window.frame
    frame:Show()
    local corner = case.rodeTo.region
    at(frame, 100, 900)
    at(corner, 93, 917)
    case.window.dockCompactIcon()
    assert(case.rodeTo.region == corner, name .. ": the same spot again")
    local left, _, top = frame:GetClampRectInsets()
    assert(left == -7 and top == 17, name .. ": still reaches over the corner, got " .. tostring(left) .. "," .. tostring(top))
  end)

  -- test_no_button_to_dock_leaves_the_clamp_flush_with_the_screen_corner
  eachLayout(function(name, compactMode)
    local dockable, case = true, nil
    case = CompactWindow.Build({
      compactLayout = compactMode,
      getDockIcon = function()
        return dockable and case.icon or nil
      end,
    })
    local frame = case.window.frame
    frame:Show()
    local corner = case.rodeTo.region
    at(frame, 100, 900)
    at(corner, 93, 917)
    frame:Hide()
    frame:Show()
    assert(select(1, frame:GetClampRectInsets()) == -7, name .. ": a docked circle reaches over its corner")
    frame:Hide()
    dockable = false
    frame:Show()
    local left, _, top = frame:GetClampRectInsets()
    assert(left == 0 and top == 0, name .. ": nothing docks, so no reach, got " .. tostring(left) .. "," .. tostring(top))
  end)

  -- test_off_open_leaves_the_corner_free_and_the_option_toggles_live
  eachLayout(function(name, compactMode)
    local dockOn = false
    local case = CompactWindow.Build({
      compactLayout = compactMode,
      isIconDockOn = function()
        return dockOn
      end,
    })
    case.window.frame:Show()
    assert(case.rides == 0 and case.rideHandlers == nil, name .. ": nothing docked, a drag moves the button")
    assert(titleOffset(case) == L.TITLE_BAR_INSET_X, name .. ": title buttons at the left edge")
    dockOn = true
    case.window.dockCompactIcon()
    assert(case.rides == 1 and titleOffset(case) == L.TITLE_BAR_INSET_X + L.COMPACT_ICON_SLOT_CLEARANCE, name .. ": OFF -> ON docks now")
    dockOn = false
    case.window.dockCompactIcon()
    assert(case.homes == 1 and titleOffset(case) == L.TITLE_BAR_INSET_X, name .. ": ON -> OFF sends it home, corner back")
  end)

  -- test_off_leaves_the_clamp_flush_with_the_screen_corner
  eachLayout(function(name, compactMode)
    local dockOn = true
    local case = CompactWindow.Build({
      compactLayout = compactMode,
      isIconDockOn = function()
        return dockOn
      end,
    })
    local frame = case.window.frame
    frame:Show()
    local corner = case.rodeTo.region
    at(frame, 100, 900)
    at(corner, 93, 917)
    frame:Hide()
    frame:Show()
    assert(select(1, frame:GetClampRectInsets()) == -7, name .. ": on: the docked circle reaches over its corner")
    frame:Hide()
    dockOn = false
    frame:Show()
    local left, _, top = frame:GetClampRectInsets()
    assert(left == 0 and top == 0, name .. ": off: no reach, got " .. tostring(left) .. "," .. tostring(top))
  end)

  -- test_a_missing_open_at_saved_spot_option_counts_as_on
  eachLayout(function(name, compactMode)
    local case = CompactWindow.Build({ compactLayout = compactMode })
    local frame = case.window.frame
    local before = { frame:GetPoint() }
    frame:Show()
    local after = { frame:GetPoint() }
    for i = 1, 5 do
      assert(after[i] == before[i], name .. ": the window opens at its saved spot, anchor part " .. i)
    end
    case.rideHandlers.endDrag()
    assert(case.adopted == 0, name .. ": and the button's home stays put")
  end)

  -- test_wrapped_position_adopts_the_buttons_spot_before_saving
  do
    local calls = {}
    local hooks = DockWiring.Hooks()
    local wrapped = DockWiring.WrapPosition(hooks, function(state)
      calls[#calls + 1] = "saved " .. state.tag
    end)
    hooks.onWindowMoved()
    wrapped({ tag = "idle" })
    assert(table.concat(calls, ",") == "saved idle", "idle hooks do nothing before the save")
    hooks.onWindowMoved = function()
      calls[#calls + 1] = "adopted"
    end
    wrapped({ tag = "moved" })
    assert(table.concat(calls, ",") == "saved idle,adopted,saved moved", "adopt first, then save, got " .. table.concat(calls, ","))
  end
end
