local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

local function build(active)
  local characterState = { window = { width = 900 } }
  local callbacks = WindowCallbacks.Create({
    runtime = { compactLayoutActive = active },
    characterState = characterState,
    defaultCharacterState = { window = { width = 900, height = 560 } },
  })
  return callbacks, characterState
end

return function()
  -- test_compact_position_saves_apart_from_the_classic_window
  do
    local callbacks, characterState = build(true)
    callbacks.onPositionChanged({ width = 360, height = 640 })
    assert(characterState.compactWindow.width == 360, "compact size saved")
    assert(characterState.window.width == 900, "classic size untouched")
  end

  -- test_compact_reset_forgets_the_compact_size_only
  do
    local callbacks, characterState = build(true)
    characterState.compactWindow = { width = 500 }
    assert(callbacks.onResetWindowPosition() == nil, "nothing to apply: the window redocks itself")
    assert(characterState.compactWindow == nil, "compact size forgotten")
    assert(characterState.window.width == 900, "classic state untouched")
  end

  -- test_classic_position_saves_as_before
  do
    local callbacks, characterState = build(nil)
    callbacks.onPositionChanged({ width = 700 })
    assert(characterState.window.width == 700 and characterState.compactWindow == nil, "classic path")
  end
end
