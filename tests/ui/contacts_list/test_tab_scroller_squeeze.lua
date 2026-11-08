local Rig = require("tests.helpers.tab_scroller_rig")

-- Fixture: 5 tabs of width 50, spacing 2, arrows 16, endReserve 0.
-- Fit room = strip width. Overflow room = width - 2*16 - 2*2 + outset
-- = width - 36 + outset. Squeeze hook (when on) draws a tab 8 px narrower,
-- so tight width = 42 (floor 0).
-- Runs: natural of n tabs = 52n - 2; tight of n tabs = 44n - 2.

local function shown(rig)
  return table.concat(Rig.shownIndices(rig), ",")
end

local function widths(rig)
  local list = {}
  for index, tab in ipairs(rig.tabs) do
    list[index] = tab.btn:GetWidth()
  end

  return table.concat(list, ",")
end

local function laidOut(opts, width)
  local rig = Rig.build(nil, opts)
  Rig.resize(rig, width)
  rig.scroller.layout(rig.visible, nil)

  return rig
end

local function wheel(rig, delta)
  rig.strip.scripts.OnMouseWheel(rig.strip, delta)
end

-- test_outset_moves_back_arrow_and_tab_chain_left
-- width 180, outset 8: room 180 - 36 + 8 = 152; 2 tabs 102, 3 tabs 154 > 152 -> 1,2.
-- Chain offset 16 + 2 - 8 = 10.
do
  local rig = laidOut({ arrowOutset = 8 }, 180)
  local back = rig.prev.points[1]
  assert(shown(rig) == "1,2", "got " .. shown(rig))
  assert(back[1] == "LEFT" and back[2] == rig.strip and back[3] == "LEFT", "back arrow anchors strip LEFT")
  assert(back[4] == -8, "back arrow x -8, got " .. tostring(back[4]))
  assert(rig.tabs[1].btn.points[1][4] == 10, "tab chain offset 10, got " .. tostring(rig.tabs[1].btn.points[1][4]))
  rig.scroller.scroll(1)
  assert(shown(rig) == "2,3", "got " .. shown(rig))
  assert(rig.tabs[2].btn.points[1][4] == 10, "offset kept after scroll, got " .. tostring(rig.tabs[2].btn.points[1][4]))
end

-- test_outset_adds_room_for_one_more_tab
-- width 182: room 146 without outset (3 tabs 154 > 146 -> 1,2), 154 with outset 8 (-> 1,2,3).
do
  assert(shown(laidOut({}, 182)) == "1,2", "no outset shows 2 tabs")
  assert(shown(laidOut({ arrowOutset = 8 }, 182)) == "1,2,3", "outset shows 3 tabs")
end

-- test_squeeze_shows_more_tabs_drawn_tight
-- width 180, room 144: tight 3 tabs 130 <= 144, 4 tabs 174 > 144; natural 3 tabs 154 > 144.
do
  local rig = laidOut({ squeeze = true }, 180)
  assert(shown(rig) == "1,2,3", "got " .. shown(rig))
  assert(widths(rig) == "42,42,42,50,50", "shown tight, hidden untouched, got " .. widths(rig))
end

-- test_view_that_fits_natural_is_drawn_natural
-- width 300 >= natural full run 258.
do
  local rig = laidOut({ squeeze = true }, 300)
  assert(shown(rig) == "1,2,3,4,5", "got " .. shown(rig))
  assert(widths(rig) == "50,50,50,50,50", "got " .. widths(rig))
  assert(rig.prev.shown == false and rig.next.shown == false, "arrows hidden")
end

-- test_full_run_that_fits_only_tight_has_no_arrows
-- width 230: natural 258 > 230, tight 218 <= 230.
do
  local rig = laidOut({ squeeze = true }, 230)
  assert(shown(rig) == "1,2,3,4,5", "got " .. shown(rig))
  assert(widths(rig) == "42,42,42,42,42", "got " .. widths(rig))
  assert(rig.prev.shown == false and rig.next.shown == false, "arrows hidden")
  assert(rig.strip.mouseWheelEnabled == false, "wheel off")
  assert(rig.tabs[1].btn.points[1][4] == 0, "tabs start at x 0")
end

-- test_overflow_run_that_fits_natural_is_drawn_natural
-- width 190, room 154: tight 3 tabs 130 fit, 4 tabs 174 do not; natural 3 tabs 154 <= 154.
do
  local rig = laidOut({ squeeze = true }, 190)
  assert(shown(rig) == "1,2,3", "got " .. shown(rig))
  assert(widths(rig) == "50,50,50,50,50", "got " .. widths(rig))
end

-- test_tabs_at_their_floor_do_not_squeeze
-- floors 50 = natural, so tight = natural; width 180 room 144: 3 tabs 154 > 144 -> 1,2.
do
  local rig = laidOut({ squeeze = true, floors = { 50, 50, 50, 50, 50 } }, 180)
  assert(shown(rig) == "1,2", "got " .. shown(rig))
  assert(widths(rig) == "50,50,50,50,50", "got " .. widths(rig))
end

-- test_widening_restores_natural_widths
do
  local rig = laidOut({ squeeze = true }, 180)
  assert(widths(rig) == "42,42,42,50,50", "squeezed first, got " .. widths(rig))
  Rig.resize(rig, 300)
  assert(widths(rig) == "50,50,50,50,50", "got " .. widths(rig))
end

-- test_wheel_at_the_tight_end_changes_nothing
-- width 180, room 144: tight run 3..5 = 130 fits, 2..5 = 174 does not -> last first-index 3.
do
  local rig = laidOut({ squeeze = true }, 180)
  rig.scroller.scroll(1)
  rig.scroller.scroll(1)
  assert(shown(rig) == "3,4,5", "got " .. shown(rig))
  assert(rig.next.enabled == false, "forward arrow disabled at the tight end")
  wheel(rig, -1)
  assert(shown(rig) == "3,4,5", "wheel down stays, got " .. shown(rig))
end

-- test_reveal_keeps_a_tight_active_tab
-- width 180, room 144: tab 3 is the last tight-fitting tab from first 1 (natural would
-- fit only tabs 1,2 and push first to 2).
do
  local rig = Rig.build(nil, { squeeze = true })
  Rig.resize(rig, 180)
  rig.scroller.layout(rig.visible, rig.tabs[3])
  assert(shown(rig) == "1,2,3", "got " .. shown(rig))
end

-- test_without_squeeze_hook_widths_never_change
do
  local rig = laidOut({}, 180)
  assert(shown(rig) == "1,2", "got " .. shown(rig))
  assert(widths(rig) == "50,50,50,50,50", "got " .. widths(rig))
end

print("PASS: test_tab_scroller_squeeze")
