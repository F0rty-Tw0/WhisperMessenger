local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

local function build(active)
  local characterState = { window = { width = 900 } }
  local callbacks = WindowCallbacks.Create({
    runtime = { phoneLayoutActive = active },
    characterState = characterState,
    defaultCharacterState = { window = { width = 900, height = 560 } },
  })
  return callbacks, characterState
end

return function()
  -- test_phone_position_saves_apart_from_the_classic_window
  do
    local callbacks, characterState = build(true)
    callbacks.onPositionChanged({ width = 360, height = 640 })
    assert(characterState.phoneWindow.width == 360, "phone size saved")
    assert(characterState.window.width == 900, "classic size untouched")
  end

  -- test_phone_reset_forgets_the_phone_size_only
  do
    local callbacks, characterState = build(true)
    characterState.phoneWindow = { width = 500 }
    assert(callbacks.onResetWindowPosition() == nil, "nothing to apply: the window redocks itself")
    assert(characterState.phoneWindow == nil, "phone size forgotten")
    assert(characterState.window.width == 900, "classic state untouched")
  end

  -- test_classic_position_saves_as_before
  do
    local callbacks, characterState = build(nil)
    callbacks.onPositionChanged({ width = 700 })
    assert(characterState.window.width == 700 and characterState.phoneWindow == nil, "classic path")
  end
end
