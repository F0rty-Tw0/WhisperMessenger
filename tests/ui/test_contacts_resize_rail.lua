local ContactsResize = require("WhisperMessenger.UI.MessengerWindow.WindowScripts.Frame.ContactsResize")
local Theme = require("WhisperMessenger.UI.Theme")

local L = Theme.LAYOUT
local COLLAPSE_BELOW = L.CONTACTS_RAIL_COLLAPSE_BELOW
local EXPAND_ABOVE = L.CONTACTS_RAIL_EXPAND_ABOVE

-- One divider drag snaps the pane to the rail and back as often as the
-- pointer crosses the snap points; while expanded the pane follows the
-- pointer. The gap between the two points stops a jittery pointer flickering.
local function newResize(startCollapsed)
  local state = { collapsed = startCollapsed == true, cursorX = 0, relayouts = {}, snaps = {}, saved = 0 }
  state.resize = ContactsResize.New({
    frameTheme = Theme,
    getCursorX = function()
      return state.cursorX
    end,
    getFrameLeft = function()
      return 0
    end,
    frameWidth = function()
      return 900
    end,
    frameHeight = function()
      return 560
    end,
    relayoutWindow = function(_w, _h, width)
      state.relayouts[#state.relayouts + 1] = width
    end,
    isCollapsed = function()
      return state.collapsed
    end,
    setCollapsed = function(collapsed, requestedWidth)
      state.snaps[#state.snaps + 1] = { collapsed = collapsed, width = requestedWidth }
      state.collapsed = collapsed
    end,
    buildState = function()
      return {}
    end,
    onPositionChanged = function()
      state.saved = state.saved + 1
    end,
  })
  return state
end

local function dragTo(state, x)
  state.cursorX = x
  state.resize.updateFromCursor()
end

return function()
  -- test_drag_above_the_collapse_point_keeps_resizing
  do
    local state = newResize(false)
    state.cursorX = 250
    state.resize.start("LeftButton")
    dragTo(state, COLLAPSE_BELOW)
    assert(#state.snaps == 0, "no snap at the collapse point")
    assert(state.relayouts[#state.relayouts] == COLLAPSE_BELOW, "pane keeps following the drag (layout clamps it)")
  end

  -- test_one_drag_snaps_back_and_forth
  do
    local state = newResize(false)
    state.cursorX = 250
    state.resize.start("LeftButton")
    dragTo(state, COLLAPSE_BELOW - 1)
    assert(#state.snaps == 1 and state.snaps[1].collapsed == true, "snaps to the rail")
    dragTo(state, 200)
    assert(#state.snaps == 2 and state.snaps[2].collapsed == false, "same drag expands again")
    assert(state.snaps[2].width == 200, "expanding follows the pointer, got " .. tostring(state.snaps[2].width))
    dragTo(state, 260)
    assert(state.relayouts[#state.relayouts] == 260, "and keeps resizing the expanded pane")
    dragTo(state, 20)
    assert(#state.snaps == 3 and state.snaps[3].collapsed == true, "and can collapse again")
    state.resize.stop("LeftButton")
    assert(state.saved == 1, "release persists the window state")
  end

  -- test_jitter_in_the_gap_never_flips
  do
    local state = newResize(true)
    state.cursorX = L.CONTACTS_RAIL_WIDTH
    state.resize.start("LeftButton")
    for _ = 1, 5 do
      dragTo(state, EXPAND_ABOVE)
      dragTo(state, COLLAPSE_BELOW)
    end
    assert(#state.snaps == 0, "rail stays put inside the gap")
    assert(#state.relayouts == 0, "and does not relayout")
  end

  -- test_dragging_the_rail_out_from_its_edge
  do
    local state = newResize(true)
    state.cursorX = L.CONTACTS_RAIL_WIDTH
    state.resize.start("LeftButton")
    dragTo(state, 80)
    dragTo(state, EXPAND_ABOVE + 1)
    assert(#state.snaps == 1 and state.snaps[1].collapsed == false, "rail expands once past the expand point")
    dragTo(state, 300)
    assert(state.relayouts[#state.relayouts] == 300, "pane follows the pointer out")
  end
end
