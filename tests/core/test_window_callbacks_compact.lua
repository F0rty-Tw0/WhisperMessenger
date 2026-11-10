local WindowCallbacks = require("WhisperMessenger.Core.Bootstrap.WindowRuntime.WindowCallbacks")

local function build(active, shared)
  local characterState = { window = { width = 900 } }
  local accountState = { settings = { shareWidgetPosition = shared == true } }
  local callbacks = WindowCallbacks.Create({
    runtime = { compactLayoutActive = active },
    accountState = accountState,
    characterState = characterState,
    defaultCharacterState = { window = { width = 900, height = 560 } },
  })
  return callbacks, characterState, accountState
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

  -- test_shared_classic_move_writes_only_the_account_spot
  do
    local callbacks, characterState, accountState = build(nil, true)
    callbacks.onPositionChanged({ x = 40, width = 700, contactsCollapsed = true })
    assert(accountState.sharedWindow.x == 40 and accountState.sharedWindow.width == 700, "account spot written")
    assert(characterState.window.width == 900 and characterState.window.x == nil, "this character's geometry untouched")
    assert(characterState.window.contactsCollapsed == true, "the collapsed rail still saves per character")
  end

  -- test_shared_compact_move_writes_the_account_compact_spot
  do
    local callbacks, characterState, accountState = build(true, true)
    callbacks.onPositionChanged({ x = 5, width = 380, compactLayout = true })
    assert(accountState.sharedCompactWindow.x == 5 and accountState.sharedCompactWindow.width == 380, "account compact spot written")
    assert(accountState.sharedWindow == nil, "the classic account spot is not touched")
    assert(characterState.compactWindow.x == nil, "this character's compact geometry untouched")
  end

  -- test_shared_classic_reset_returns_the_default_spot_for_the_window_to_apply
  do
    local callbacks, characterState, accountState = build(nil, true)
    accountState.sharedWindow = { x = 40, width = 700 }
    local nextState = callbacks.onResetWindowPosition()
    assert(nextState.width == 900 and nextState.height == 560, "the default size is applied")
    assert(accountState.sharedWindow.width == 900, "the account spot is reset")
    assert(characterState.window.width == 900, "this character's own spot was not the one reset")
  end

  -- test_shared_compact_reset_stops_the_next_login_from_reseeding
  do
    local callbacks, characterState, accountState = build(true, true)
    accountState.sharedCompactWindow = { x = 40, width = 380 }
    characterState.compactWindow = { x = 1, width = 300 }
    assert(callbacks.onResetWindowPosition() == nil, "nothing to apply: the window redocks itself")
    assert(next(accountState.sharedCompactWindow) == nil, "the account compact spot is the default marker")
    assert(characterState.compactWindow.x == 1, "this character's compact spot is kept for sharing off")
  end
end
