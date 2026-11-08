local CompactWindow = require("tests.helpers.compact_window")
local Rig = require("tests.helpers.grow_rig")
local GrowWorld = require("tests.helpers.grow_world")

local STEP = Rig.STEP
local DONE, ICON_A, ICON_B = GrowWorld.DONE, GrowWorld.ICON_A, GrowWorld.ICON_B
local eachStyle = GrowWorld.EachStyle
local settled, open, aimedAt = GrowWorld.Settled, GrowWorld.Open, GrowWorld.AimedAt

-- Spec section 5 (state x event table), event rows: drag, switch, icon mode, scale.
-- The open, close, completion and Alt+Z rows are in test_window_grow_state_table.lua.

-- Spec 5, row "Window drag": Opening aims at the live rect; Open saves the window spot only.
local function test_window_drag()
  eachStyle(function(w, style)
    w.frame:Show()
    Rig.tick(w.ghost, STEP * 2)
    Rig.rect(w.frame, 300, 100, 660, 740)
    w.frame.scripts.OnDragStop(w.frame)
    aimedAt(w, STEP * 2, { 480, 420 }, style .. " dragged while growing")
    Rig.tick(w.ghost, DONE)
    settled(w, style .. " grown")
  end)
  eachStyle(function(w, style)
    open(w)
    w.frame.scripts.OnDragStop(w.frame)
    assert(w.case.saved.state ~= nil, style .. ": the window spot is saved")
    settled(w, style .. " drag leaves it open")
  end)
  -- With the button docked (D1): the drag saves the window and leaves the button's home alone.
  local case = CompactWindow.Build()
  case.window.frame:Show()
  case.window.frame.scripts.OnDragStop(case.window.frame)
  assert(case.saved.state ~= nil, "compact, docked: the window spot is saved")
  assert(case.homeMoves == 0 and case.homes == 0, "compact, docked: the button's home is unchanged")
end

-- Spec 5, row "Switch toggled": Opening and Closing finish as started; Closed applies at the next open; Open at the next close.
local function test_switch_toggled()
  eachStyle(function(w, style)
    w.frame:Show()
    Rig.tick(w.ghost, STEP * 2)
    local width = w.ghost.width
    w.on = false
    assert(Rig.running(w.ghost), style .. ": the grow is not cut short")
    Rig.tick(w.ghost, STEP)
    assert(w.ghost.width > width, style .. ": and carries on")
    Rig.tick(w.ghost, DONE)
    settled(w, style .. " grown after the switch went off")
  end)
  eachStyle(function(w, style)
    open(w)
    w.frame:Hide()
    Rig.tick(w.ghost, STEP * 2)
    local width = w.ghost.width
    w.on = false
    assert(Rig.running(w.ghost), style .. ": the shrink is not cut short")
    Rig.tick(w.ghost, STEP)
    assert(w.ghost.width < width, style .. ": and carries on")
    Rig.tick(w.ghost, DONE)
    settled(w, style .. " shrunk after the switch went off")
  end)
  eachStyle(function(w, style)
    w.on = false
    w.frame:Show()
    w.frame:Hide()
    settled(w, style .. " off: opens and closes at once")
    w.on = true
    w.frame:Show()
    assert(w.ghost:IsShown() and Rig.running(w.ghost), style .. ": back on, the next open grows")
  end)
  eachStyle(function(w, style)
    open(w)
    w.on = false
    settled(w, style .. " open stays open when the switch goes off")
    w.frame:Hide()
    settled(w, style .. " and the next close is instant")
  end)
end

-- Spec 5, row "Icon mode change": Open re-resolves at the next close (classic) and the compact window docks nothing here;
-- Closing runs into the remembered source. Compact-window Opening and Open with a docked button: test_compact_layout.lua.
local function test_icon_mode_change()
  eachStyle(function(w, style)
    open(w)
    w.source = w.iconB -- the mode moved the icon: A is gone, B is the source now
    w.iconA:Hide()
    w.frame:Hide()
    aimedAt(w, 0, ICON_B, style .. " closes into the new source")
  end)
  eachStyle(function(w, style)
    open(w)
    w.source = w.iconB -- A is still shown: the close keeps the source it grew from
    w.frame:Hide()
    aimedAt(w, 0, ICON_A, style .. " closes into the remembered source")
  end)
  eachStyle(function(w, style)
    open(w)
    w.frame:Hide()
    Rig.tick(w.ghost, STEP * 2)
    w.source = w.iconB
    w.iconA:Hide()
    aimedAt(w, STEP * 2, ICON_A, style .. " closing runs on")
    Rig.tick(w.ghost, DONE)
    settled(w, style .. " closed")
  end)
end

-- Spec 5, row "Scale change": compact-window Opening, a button-driven grow: dock() finishes it. Classic has no cell.
local function test_scale_change_finishes_a_button_driven_opening()
  local case = CompactWindow.Build()
  local frame = case.window.frame
  frame:Show()
  local step = case.step
  assert(step ~= nil and case.instant ~= true, "the button's glide drives the grow")
  step(0.5, 0.9)
  assert(frame:GetAlpha() < 1, "held unseen mid-grow")
  case.window.setScale(1)
  assert(case.rides == 2, "the button takes its spot again")
  assert(frame:GetAlpha() == 1, "dock() releases the hold, got " .. tostring(frame:GetAlpha()))
  step(0.6, 0.95)
  assert(frame:GetAlpha() == 1, "the old glide's late step does nothing")
end

return function()
  test_window_drag()
  test_switch_toggled()
  test_icon_mode_change()
  test_scale_change_finishes_a_button_driven_opening()
end
