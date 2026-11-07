local FindUI = require("tests.helpers.find_ui")
local Rig = require("tests.helpers.tab_scroller_rig")

-- Fixture: 5 tabs of width 50, spacing 2, arrows 16 wide, no end reserve.
-- Sum = 5 * 50 + 4 * 2 = 258; in overflow available = strip width - 34.

local function shown(rig)
  return table.concat(Rig.shownIndices(rig), ",")
end

local function layoutAt(rig, width)
  rig.strip:SetWidth(width)
  rig.scroller.layout(rig.visible, nil)
end

-- test_zero_width_strip_counts_as_fits
do
  local rig = Rig.build()
  rig.scroller.layout(rig.visible, nil)
  assert(shown(rig) == "1,2,3,4,5", "all tabs show, got " .. shown(rig))
  assert(rig.prev.shown == false and rig.next.shown == false, "arrows hidden")
  assert(rig.strip.mouseWheelEnabled == false, "wheel off while fitting")
end

-- test_tabs_chain_from_the_strip_left_edge
do
  local rig = Rig.build()
  rig.scroller.layout(rig.visible, nil)
  local first, second = rig.tabs[1].btn.points[1], rig.tabs[2].btn.points[1]
  assert(first[1] == "TOPLEFT" and first[2] == rig.strip and first[3] == "TOPLEFT" and first[4] == 0, "first tab at the strip's left")
  assert(second[1] == "TOPLEFT" and second[2] == rig.tabs[1].btn and second[3] == "TOPRIGHT" and second[4] == 2, "second tab 2px right of the first")
end

-- test_exact_fit_shows_no_arrows
do
  local rig = Rig.build()
  layoutAt(rig, 258)
  assert(shown(rig) == "1,2,3,4,5", "got " .. shown(rig))
  assert(rig.prev.shown == false and rig.next.shown == false, "arrows hidden")
end

-- test_one_pixel_short_overflows
do
  local rig = Rig.build()
  layoutAt(rig, 257)
  assert(shown(rig) == "1,2,3,4", "got " .. shown(rig))
  assert(rig.prev.shown == true and rig.next.shown == true, "arrows shown")
  assert(rig.prev.enabled == false and rig.next.enabled == true, "back disabled at the start, forward enabled")
  assert(rig.strip.mouseWheelEnabled == true, "wheel on while overflowing")
end

-- test_run_exactly_filling_available_shows_whole_run
do
  local rig = Rig.build()
  layoutAt(rig, 188)
  assert(shown(rig) == "1,2,3", "got " .. shown(rig))
end

-- test_over_wide_first_tab_still_shows
do
  local rig = Rig.build({ 300, 50, 50, 50, 50 })
  layoutAt(rig, 200)
  assert(shown(rig) == "1", "got " .. shown(rig))
end

-- test_end_reserve_counts_in_fit
do
  local rig = Rig.build(nil, { endReserve = 7 })
  layoutAt(rig, 265)
  assert(shown(rig) == "1,2,3,4,5" and rig.next.shown == false, "265 fits")
  layoutAt(rig, 264)
  assert(rig.next.shown == true, "264 overflows")
end

-- test_arrows_pin_to_the_strip_right_end
do
  local rig = Rig.build()
  local forward, back = rig.next.points[1], rig.prev.points[1]
  assert(
    forward[1] == "RIGHT" and forward[2] == rig.strip and forward[3] == "RIGHT" and forward[4] == 0 and forward[5] == 0,
    "next at the strip's right edge"
  )
  assert(back[1] == "RIGHT" and back[2] == rig.next and back[3] == "LEFT" and back[4] == 0 and back[5] == 0, "prev touches next's left")
end

-- test_arrows_live_in_a_holder_under_the_strip
do
  local rig = Rig.build()
  local holder = FindUI.ofType(rig.strip, "Frame")[1]
  assert(#FindUI.ofType(rig.strip, "Button") == 5, "only the tabs are Button children of the strip")
  assert(holder ~= nil and holder:GetParent() == rig.strip, "holder is a child of the strip")
  assert(rig.prev:GetParent() == holder and rig.next:GetParent() == holder, "arrows sit in the holder")
end

-- test_paint_arrow_reports_enabled_state
do
  local rig = Rig.build()
  layoutAt(rig, 257)
  assert(#rig.painted == 2, "one paint per arrow, got " .. #rig.painted)
  assert(rig.painted[1].btn == rig.prev and rig.painted[1].enabled == false, "prev painted disabled")
  assert(rig.painted[2].btn == rig.next and rig.painted[2].enabled == true, "next painted enabled")
  rig.painted = {}
  rig.scroller.paintArrows()
  assert(#rig.painted == 2, "paintArrows repaints both, got " .. #rig.painted)
  assert(rig.painted[1].btn == rig.prev and rig.painted[1].enabled == false, "prev repainted disabled")
  assert(rig.painted[2].btn == rig.next and rig.painted[2].enabled == true, "next repainted enabled")
end

print("PASS: test_tab_scroller_layout")
