-- At a screen edge the window keeps HIGH strata: the highest one that still
-- draws under the addon's own DIALOG popups, the colour picker and tooltips.
local CompactWindow = require("tests.helpers.compact_window")

local function shown(edgeSide)
  local config = { showGroupChats = true, screenEdge = edgeSide }
  local case = CompactWindow.Build({ settingsConfig = config })
  CompactWindow.Lay(case)
  case.config = config
  case.frame = case.window.frame
  case.frame:Show()
  return case
end

local function clickElsewhere(case)
  local savedFoci, savedFocus = rawget(_G, "GetMouseFoci"), rawget(_G, "GetMouseFocus")
  rawset(_G, "GetMouseFoci", nil)
  rawset(_G, "GetMouseFocus", nil)
  rawset(case.frame, "IsMouseOver", function()
    return false
  end)
  local ok, err = pcall(case.frame.scripts.OnEvent, case.frame, "GLOBAL_MOUSE_DOWN")
  rawset(_G, "GetMouseFoci", savedFoci)
  rawset(_G, "GetMouseFocus", savedFocus)
  assert(ok, err)
end

return function()
  -- test_outside_click_leaves_a_docked_window_high
  for _, side in ipairs({ "left", "right" }) do
    local case = shown(side)
    clickElsewhere(case)
    assert(case.frame:GetFrameStrata() == "HIGH", side .. ": stays HIGH, got " .. case.frame:GetFrameStrata())
  end

  -- test_outside_click_still_demotes_a_floating_window
  do
    local case = shown("off")
    clickElsewhere(case)
    assert(case.frame:GetFrameStrata() == "MEDIUM", "floating: demotes")
  end

  -- test_docking_a_demoted_window_raises_it: picking the side from a dropdown
  -- menu is a click outside the window, so it is MEDIUM when the side changes.
  do
    local case = shown("off")
    clickElsewhere(case)
    case.config.screenEdge = "left"
    case.window.applyScreenEdge()
    assert(case.frame:GetFrameStrata() == "HIGH", "docked live: raised")
  end

  -- test_undocked_window_demotes_again
  do
    local case = shown("left")
    case.config.screenEdge = "off"
    case.window.applyScreenEdge()
    clickElsewhere(case)
    assert(case.frame:GetFrameStrata() == "MEDIUM", "edge off: demotes again")
  end
end
