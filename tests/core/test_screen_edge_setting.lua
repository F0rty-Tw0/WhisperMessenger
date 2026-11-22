local ScreenEdgeSetting = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.ScreenEdgeSetting")

local SLOT = { x = 1 }

local function build(withWindow)
  local case = { applied = {}, ensured = 0, updated = 0 }
  local runtime = {}
  if withWindow then
    runtime.window = {
      applyScreenEdge = function(state)
        case.applied[#case.applied + 1] = state
      end,
    }
  end
  case.ctx = {
    runtime = runtime,
    ensureSurface = function()
      case.ensured = case.ensured + 1
    end,
    updateIconSurfaces = function()
      case.updated = case.updated + 1
    end,
    readCompactSlot = function()
      return SLOT
    end,
  }
  return case
end

return function()
  -- test_screen_edge_applies_to_the_window_with_the_saved_compact_spot
  do
    local case = build(true)
    ScreenEdgeSetting.Apply(case.ctx, "screenEdge", "left")
    assert(#case.applied == 1 and case.applied[1] == SLOT, "applyScreenEdge got the saved compact slot")
  end

  -- test_each_key_builds_and_refreshes_the_surface
  for _, key in ipairs({ "screenEdge", "edgeGlow", "edgeGlowColor", "edgeGlowCustom" }) do
    local case = build(true)
    ScreenEdgeSetting.Apply(case.ctx, key, key == "screenEdge" and "right" or false)
    assert(case.ensured == 1 and case.updated == 1, key .. " builds and refreshes the surface")
  end

  -- test_glow_does_not_move_the_window
  do
    local case = build(true)
    ScreenEdgeSetting.Apply(case.ctx, "edgeGlow", false)
    assert(#case.applied == 0, "window untouched")
  end

  -- test_other_keys_do_nothing
  do
    local case = build(true)
    for _, key in ipairs({ "iconDock", "edgeHandle", "widgetShape", "iconBorder", "iconBackground", "iconBorderThemed", "widgetTransparency" }) do
      ScreenEdgeSetting.Apply(case.ctx, key, true)
    end
    assert(#case.applied == 0 and case.ensured == 0 and case.updated == 0, "ignored")
  end

  -- test_no_window_yet_still_refreshes_the_surface
  do
    local case = build(false)
    ScreenEdgeSetting.Apply(case.ctx, "screenEdge", "left")
    assert(case.ensured == 1 and case.updated == 1, "surface still refreshed")
  end
end
