local Rig = require("tests.helpers.grow_rig")
local GrowWorld = require("tests.helpers.grow_world")

local STEP = Rig.STEP
local DONE, WIDTH, ICON_A = GrowWorld.DONE, GrowWorld.WIDTH, GrowWorld.ICON_A
local eachStyle, eachInstant = GrowWorld.EachStyle, GrowWorld.EachInstant
local settled, open, aimedAt = GrowWorld.Settled, GrowWorld.Open, GrowWorld.AimedAt

-- Spec section 5 (state x event table), event rows: open, close, completion, Alt+Z.
-- The drag, switch, icon mode and scale rows are in test_window_grow_state_table_events.lua.

-- Spec 5, row "Open, switch on, source": all four states.
local function test_open_with_switch_on_and_a_source()
  eachStyle(function(w, style)
    w.frame:Show() -- Closed -> Opening
    assert(w.frame:GetAlpha() == 0 and w.ghost:IsShown() and Rig.running(w.ghost), style .. ": grows from the icon")
    Rig.tick(w.ghost, STEP * 2)
    local width = w.ghost.width
    Rig.parentShows(w.frame) -- Opening: ignored
    Rig.tick(w.ghost, STEP)
    assert(w.ghost.width > width, style .. ": same run, not restarted")
    Rig.tick(w.ghost, DONE)
    Rig.parentShows(w.frame) -- Open: ignored
    settled(w, style .. " open stays open")
    w.frame:Hide() -- Open -> Closing
    Rig.tick(w.ghost, STEP * 2)
    assert(w.ghost.width > 1 and w.ghost.width < WIDTH, style .. ": mid shrink")
    w.frame:Show() -- Closing: supersede -> Opening
    assert(w.ghost.width <= 1, style .. ": the shrink gave way to a fresh grow")
    Rig.tick(w.ghost, DONE)
    settled(w, style .. " reopened")
  end)
end

-- Spec 5, row "Open, switch off or no source": Closed -> Open instantly; Open: ignored; Closing -> Open instantly.
local function test_open_with_switch_off_or_no_source()
  eachInstant(function(w, label, apply)
    apply(w)
    w.frame:Show() -- Closed
    settled(w, label .. ", from closed")
    Rig.parentShows(w.frame) -- Open: ignored
    settled(w, label .. ", shown again")
  end)
  eachInstant(function(w, label, apply)
    open(w)
    w.frame:Hide()
    Rig.tick(w.ghost, STEP * 2)
    assert(w.ghost:IsShown() and Rig.running(w.ghost), label .. ": shrinking before the cause applies")
    apply(w)
    w.frame:Show() -- Closing: supersede
    settled(w, label .. ", from closing")
  end)
end

-- Spec 5, row "Close, switch on, source": Opening -> supersede grow, Open -> Closing.
local function test_close_with_switch_on_and_a_source()
  eachStyle(function(w, style)
    open(w)
    w.frame:Hide() -- Open -> Closing, into icon A
    assert(w.ghost:IsShown() and w.ghost.width == WIDTH, style .. ": the shrink starts as the window")
    aimedAt(w, 0, ICON_A, style .. " closing")
    Rig.tick(w.ghost, DONE)
    settled(w, style .. " closed")
  end)
  eachStyle(function(w, style)
    w.frame:Show()
    Rig.tick(w.ghost, STEP * 3)
    w.frame:Hide() -- Opening -> Closing
    assert(w.frame:GetAlpha() == 1, style .. ": the grow's hold on the window is released")
    assert(w.ghost:IsShown() and w.ghost.width == WIDTH, style .. ": the shrink starts as the window")
    aimedAt(w, 0, ICON_A, style .. " closing from a grow")
    Rig.tick(w.ghost, DONE)
    settled(w, style .. " closed from a grow")
  end)
end

-- Spec 5, row "Close, switch off or no source": Opening -> Closed instantly, Open -> Closed instantly.
local function test_close_with_switch_off_or_no_source()
  eachInstant(function(w, label, apply)
    open(w)
    apply(w)
    w.frame:Hide() -- Open
    settled(w, label .. ", from open")
  end)
  eachInstant(function(w, label, apply)
    w.frame:Show()
    Rig.tick(w.ghost, STEP * 3)
    assert(w.frame:GetAlpha() < 1, label .. ": held unseen while it grows")
    apply(w)
    w.frame:Hide() -- Opening: finish
    settled(w, label .. ", from opening")
  end)
end

-- Spec 5, row "Animation completes": Opening -> Open (alpha released), Closing -> Closed (panel hidden).
local function test_animation_completes()
  eachStyle(function(w, style)
    w.frame:Show()
    Rig.tick(w.ghost, DONE)
    settled(w, style .. " opened")
    w.frame:Hide()
    Rig.tick(w.ghost, DONE)
    settled(w, style .. " closed")
    assert(not w.frame:IsShown(), style .. ": the window stays hidden")
  end)
end

-- Spec 5, row "Alt+Z hide / show": Opening keeps its state and does not replay; Open is not a close.
local function test_alt_z_hide_and_show()
  eachStyle(function(w, style)
    open(w)
    Rig.parentHides(w.frame)
    settled(w, style .. " parent hid an open window")
    Rig.parentShows(w.frame)
    settled(w, style .. " and it came back")
  end)
  eachStyle(function(w, style)
    w.frame:Show()
    Rig.tick(w.ghost, STEP * 2)
    local width = w.ghost.width
    Rig.parentHides(w.frame)
    assert(w.ghost:IsShown() and Rig.running(w.ghost) and w.ghost.width == width, style .. ": the grow keeps its state")
    Rig.parentShows(w.frame)
    assert(w.ghost.width == width, style .. ": no replay from a point")
    Rig.tick(w.ghost, STEP)
    assert(w.ghost.width > width, style .. ": the same run carries on")
    Rig.tick(w.ghost, DONE)
    settled(w, style .. " finished")
  end)
end

return function()
  test_open_with_switch_on_and_a_source()
  test_open_with_switch_off_or_no_source()
  test_close_with_switch_on_and_a_source()
  test_close_with_switch_off_or_no_source()
  test_animation_completes()
  test_alt_z_hide_and_show()
end
