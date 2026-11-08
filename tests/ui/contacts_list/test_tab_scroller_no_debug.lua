-- The WoW client may not expose Lua's debug library; the scroller must still
-- place tabs and surface layout errors without it.
local savedDebug = _G.debug
_G.debug = nil

local Rig = require("tests.helpers.tab_scroller_rig")

local WIDTH = 400

local function shown(rig)
  return table.concat(Rig.shownIndices(rig), ",")
end

-- test_places_tabs_without_the_debug_library
do
  local rig = Rig.build({ 50, 50, 50 }, { squeeze = true })
  rig.strip:SetWidth(WIDTH)
  local ok, err = pcall(rig.scroller.layout, rig.visible, nil)
  assert(ok, "layout runs without the debug library, got " .. tostring(err))
  assert(shown(rig) == "1,2,3", "every tab shows, got " .. shown(rig))
end

-- test_a_failed_place_surfaces_and_recovers_without_the_debug_library
do
  local armed = true
  local rig = Rig.build({ 50, 50, 50 }, {
    squeeze = true,
    onSqueeze = function()
      if armed then
        armed = false
        error("boom")
      end
    end,
  })
  rig.strip:SetWidth(WIDTH)
  local ok, err = pcall(rig.scroller.layout, rig.visible, nil)
  assert(not ok, "the error surfaces")
  assert(string.find(tostring(err), "boom", 1, true), "the error keeps its message, got " .. tostring(err))
  rig.scroller.layout(rig.visible, nil)
  assert(shown(rig) == "1,2,3", "places again after an error, got " .. shown(rig))
end

_G.debug = savedDebug
print("PASS: test_tab_scroller_no_debug")
