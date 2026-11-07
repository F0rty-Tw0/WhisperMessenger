local Rig = require("tests.helpers.tab_scroller_rig")

-- Fixture as in test_tab_scroller_squeeze: 5 tabs of width 50, spacing 2,
-- arrows 16, squeeze hook narrows a tab by 8 (tight 42). Width 180: room 144,
-- so tabs 1,2,3 show, drawn tight ("42,42,42,50,50").
-- The squeeze hook below calls the scroller back, the way a width read that
-- fires OnSizeChanged does in the game.

local WIDTH = 180

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

local function reference(list)
  local rig = Rig.build(nil, { squeeze = true })
  Rig.resize(rig, WIDTH)
  rig.scroller.layout(list and list(rig) or rig.visible, nil)

  return rig
end

-- test_refresh_inside_a_measure_does_not_nest
do
  local calls = 0
  local nestedCalls = nil
  local armed = true
  local rig = Rig.build(nil, {
    squeeze = true,
    onSqueeze = function(self, _tab, _px)
      calls = calls + 1
      if armed then
        armed = false
        local before = calls
        self.scroller.refresh()
        nestedCalls = calls - before
      end
    end,
  })
  Rig.resize(rig, WIDTH)
  rig.scroller.layout(rig.visible, nil)
  assert(nestedCalls == 0, "refresh returns without measuring inside a measure, ran " .. tostring(nestedCalls) .. " squeezes")
end

-- test_refresh_inside_a_measure_ends_in_the_same_view
do
  local fired = false
  local rig = Rig.build(nil, {
    squeeze = true,
    onSqueeze = function(self)
      if not fired then
        fired = true
        self.scroller.refresh()
      end
    end,
  })
  Rig.resize(rig, WIDTH)
  rig.scroller.layout(rig.visible, nil)
  local expected = reference()
  assert(shown(rig) == shown(expected), "shown " .. shown(rig) .. ", want " .. shown(expected))
  assert(widths(rig) == widths(expected), "widths " .. widths(rig) .. ", want " .. widths(expected))
end

-- test_refresh_on_every_squeeze_settles
do
  local rig = Rig.build(nil, {
    squeeze = true,
    onSqueeze = function(self)
      self.scroller.refresh()
    end,
  })
  Rig.resize(rig, WIDTH)
  rig.scroller.layout(rig.visible, nil)
  local expected = reference()
  assert(shown(rig) == shown(expected), "shown " .. shown(rig) .. ", want " .. shown(expected))
  assert(widths(rig) == widths(expected), "widths " .. widths(rig) .. ", want " .. widths(expected))
end

-- test_layout_inside_a_measure_places_the_newest_list
-- A shorter list (tabs 1,2,3,5) laid out from inside the measure of the full
-- one ends as if it had been laid out alone: 4 tabs, tight 4 * 44 - 2 = 174 > 144
-- overflow, so tabs 1,2,3 show.
do
  local fired = false
  local rig = Rig.build(nil, {
    squeeze = true,
    onSqueeze = function(self)
      if not fired then
        fired = true
        local tabs = self.tabs
        self.scroller.layout({ tabs[1], tabs[2], tabs[3], tabs[5] }, nil)
      end
    end,
  })
  Rig.resize(rig, WIDTH)
  rig.scroller.layout(rig.visible, nil)
  local expected = reference(function(self)
    return { self.tabs[1], self.tabs[2], self.tabs[3], self.tabs[5] }
  end)
  assert(shown(rig) == shown(expected), "shown " .. shown(rig) .. ", want " .. shown(expected))
  assert(widths(rig) == widths(expected), "widths " .. widths(rig) .. ", want " .. widths(expected))
end

-- test_a_failed_place_does_not_block_the_next_one
do
  local armed = true
  local rig = Rig.build(nil, {
    squeeze = true,
    onSqueeze = function()
      if armed then
        armed = false
        error("boom")
      end
    end,
  })
  rig.strip:SetWidth(WIDTH)
  assert(not pcall(rig.scroller.layout, rig.visible, nil), "the error surfaces")
  rig.scroller.layout(rig.visible, nil)
  assert(shown(rig) == "1,2,3", "places again after an error, got " .. shown(rig))
end

print("PASS: test_tab_scroller_reentry")
