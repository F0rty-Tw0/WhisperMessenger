local Rig = require("tests.helpers.tab_scroller_rig")

-- Fixture: 5 tabs of width 50, spacing 2, arrows 16 wide. At strip width 150
-- two tabs fit per view (available 116) and the last first-index is 4.

local function shown(rig)
  return table.concat(Rig.shownIndices(rig), ",")
end

local function click(btn)
  btn.scripts.OnClick(btn)
end

local function wheel(rig, delta)
  rig.strip.scripts.OnMouseWheel(rig.strip, delta)
end

local function narrowRig()
  local rig = Rig.build()
  Rig.resize(rig, 150)
  rig.scroller.layout(rig.visible, nil)
  return rig
end

local function clickTimes(btn, times)
  for _ = 1, times do
    click(btn)
  end
end

-- test_next_arrow_moves_one_tab
do
  local rig = narrowRig()
  click(rig.next)
  assert(shown(rig) == "2,3", "got " .. shown(rig))
  assert(rig.prev.enabled == true, "back arrow enabled once scrolled")
end

-- test_next_arrow_stops_at_the_end
do
  local rig = narrowRig()
  clickTimes(rig.next, 3)
  assert(shown(rig) == "4,5", "got " .. shown(rig))
  assert(rig.next.enabled == false, "forward arrow disabled at the end")
  click(rig.next)
  assert(shown(rig) == "4,5", "stays at the end, got " .. shown(rig))
end

-- test_prev_arrow_ignored_at_start
do
  local rig = narrowRig()
  click(rig.prev)
  assert(shown(rig) == "1,2", "got " .. shown(rig))
end

-- test_prev_arrow_moves_back
do
  local rig = narrowRig()
  clickTimes(rig.next, 2)
  click(rig.prev)
  assert(shown(rig) == "2,3", "got " .. shown(rig))
end

-- test_wheel_down_scrolls_forward
do
  local rig = narrowRig()
  wheel(rig, -1)
  assert(shown(rig) == "2,3", "down: got " .. shown(rig))
  wheel(rig, 1)
  assert(shown(rig) == "1,2", "up: got " .. shown(rig))
end

-- test_wheel_ignored_at_both_ends
do
  local rig = narrowRig()
  wheel(rig, 1)
  assert(shown(rig) == "1,2", "up at start: got " .. shown(rig))
  clickTimes(rig.next, 3)
  wheel(rig, -1)
  assert(shown(rig) == "4,5", "down at end: got " .. shown(rig))
end

-- test_wheel_and_scroll_ignored_while_fitting
do
  local rig = narrowRig()
  Rig.resize(rig, 258)
  wheel(rig, -1)
  rig.scroller.scroll(1)
  assert(shown(rig) == "1,2,3,4,5", "got " .. shown(rig))
  assert(rig.strip.mouseWheelEnabled == false, "wheel off while fitting")
end

-- test_layout_reveals_active_tab_after_the_view
do
  local rig = narrowRig()
  rig.scroller.layout(rig.visible, rig.tabs[5])
  assert(shown(rig) == "4,5", "got " .. shown(rig))
end

-- test_layout_reveals_active_tab_before_the_view
do
  local rig = narrowRig()
  clickTimes(rig.next, 3)
  rig.scroller.layout(rig.visible, rig.tabs[1])
  assert(shown(rig) == "1,2", "got " .. shown(rig))
end

-- test_reveal_moves_the_minimum
do
  local rig = narrowRig()
  rig.scroller.layout(rig.visible, rig.tabs[3])
  assert(shown(rig) == "2,3", "got " .. shown(rig))
end

-- test_shown_active_tab_keeps_position
do
  local rig = narrowRig()
  click(rig.next)
  rig.scroller.layout(rig.visible, rig.tabs[3])
  assert(shown(rig) == "2,3", "got " .. shown(rig))
end

-- test_nil_or_foreign_active_tab_does_not_reveal
do
  local rig = narrowRig()
  clickTimes(rig.next, 2)
  rig.scroller.layout(rig.visible, nil)
  assert(shown(rig) == "3,4", "nil: got " .. shown(rig))
  rig.scroller.layout(rig.visible, { btn = rig.factory.CreateFrame("Button", nil, rig.strip) })
  assert(shown(rig) == "3,4", "foreign: got " .. shown(rig))
end

-- test_manual_scroll_survives_until_resize
do
  local rig = narrowRig()
  rig.scroller.layout(rig.visible, rig.tabs[1])
  clickTimes(rig.next, 3)
  assert(shown(rig) == "4,5", "scrolling away from the active tab sticks, got " .. shown(rig))
  Rig.resize(rig, 160)
  assert(shown(rig) == "1,2", "resize reveals the active tab again, got " .. shown(rig))
end

-- test_widening_clamps_first_with_no_end_gap
do
  local rig = narrowRig()
  clickTimes(rig.next, 3)
  Rig.resize(rig, 210)
  assert(shown(rig) == "3,4,5", "got " .. shown(rig))
end

-- test_widening_to_fit_shows_every_tab
do
  local rig = narrowRig()
  clickTimes(rig.next, 3)
  Rig.resize(rig, 258)
  assert(shown(rig) == "1,2,3,4,5", "got " .. shown(rig))
  assert(rig.prev.shown == false and rig.next.shown == false, "arrows hidden")
  assert(rig.tabs[1].btn.points[1][2] == rig.strip, "first tab anchored to the strip again")
end

-- test_narrowing_from_fit_reveals_active
do
  local rig = narrowRig()
  Rig.resize(rig, 258)
  rig.scroller.layout(rig.visible, rig.tabs[4])
  Rig.resize(rig, 150)
  assert(shown(rig) == "3,4", "got " .. shown(rig))
end

print("PASS: test_tab_scroller_scroll")
